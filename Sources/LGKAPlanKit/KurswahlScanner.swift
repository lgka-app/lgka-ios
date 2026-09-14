import Foundation
import CoreGraphics
import ImageIO
import Vision
import LGKACore

/// Reads a photo of a Kurswahlprotokoll on the device (Apple Vision, nothing leaves the phone).
///
/// Two passes: the whole sheet first, which finds the subject column and the "Summen" row; then
/// only the table between them, cropped and enlarged, which reads the small bracketed parallel
/// course numbers ("5(3)") far more reliably than the first pass.
public enum KurswahlScanner {
    public struct Result: Codable, Sendable {
        public var kurswahl: Kurswahl
        /// Every recognised box of both passes of the first photo, 0…1 of that image.
        public var boxes: [TextBox]
        /// Image height ÷ width of the first photo.
        public var aspect: Double
        /// Every photo's boxes, for replaying a multi-photo scan.
        public var shots: [Shot]?
        /// Where the time went, in seconds: "photo1"… (first reading of each photo), "first" (all of them),
        /// "merge", "extra" (reading gaps again), "total"; "extraRegions" is the number of regions read again.
        public var seconds: [String: Double]?

        public init(kurswahl: Kurswahl, boxes: [TextBox], aspect: Double, shots: [Shot]? = nil, seconds: [String: Double]? = nil) {
            self.kurswahl = kurswahl
            self.boxes = boxes
            self.aspect = aspect
            self.shots = shots
            self.seconds = seconds
        }
    }

    public struct Shot: Codable, Sendable {
        public var boxes: [TextBox]
        public var aspect: Double

        public init(boxes: [TextBox], aspect: Double) {
            self.boxes = boxes
            self.aspect = aspect
        }
    }

    /// Decodes a photo with its EXIF orientation applied, at most `maxPixels` on the long side.
    public static func image(from data: Data, maxPixels: Int = 4096) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    public static func read(_ image: CGImage) async throws -> Result {
        try await read([image])
    }

    /// How long reading may take before the extra passes stop. The first reading of every photo
    /// always runs; the extra passes only use what is left of this.
    public static let defaultBudget: Duration = .seconds(5)

    /// Several photos of one sheet (overview and close-ups): each read on its own, then merged cell by cell.
    /// When the merged sheet is incomplete (a sum not matched, a cell unread) and time is left, the
    /// best photo is read again where the gaps are, only ever adding to the merged reading.
    public static func read(_ images: [CGImage], budget: Duration = defaultBudget) async throws -> Result {
        let clock = ContinuousClock()
        let start = clock.now
        let deadline = start + budget
        func seconds(_ duration: Duration) -> Double {
            Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        }
        var shots: [Shot] = []
        var readings: [(image: CGImage, boxes: [TextBox], aspect: Double, detail: KurswahlParser.Detail)] = []
        var firstError: (any Error)?
        var timings: [String: Double] = [:]
        for (index, image) in images.enumerated() {
            let photoStart = clock.now
            let boxes = try await tableBoxes(image)
            let aspect = Double(image.height) / Double(max(1, image.width))
            shots.append(Shot(boxes: boxes, aspect: aspect))
            do {
                readings.append((image, boxes, aspect, try KurswahlParser.parseDetailed(boxes, aspect: aspect)))
            } catch {
                firstError = firstError ?? error
            }
            timings["photo\(index + 1)"] = seconds(clock.now - photoStart)
        }
        let firstDone = clock.now
        // Each photo not read completely gets its gaps read again in enlarged bands (plain and with the contrast
        // stretched), filled into that photo's reading before the burst is merged; nothing starts after the deadline
        var sheets: [Kurswahl] = []
        var regionsRead = 0
        for reading in readings {
            var sheet = reading.detail.kurswahl
            if !KurswahlParser.isComplete(sheet), clock.now < deadline {
                var extra: [TextBox] = []
                for region in recheckRegions(reading.detail) {
                    guard clock.now < deadline else { break }
                    extra += await recognizeClamped(reading.image, region: region, options: PassOptions(maxScale: 8), deadline: deadline)
                    extra += await recognizeClamped(reading.image, region: region, options: PassOptions(contrast: true, maxScale: 8), deadline: deadline)
                    regionsRead += 1
                }
                if !extra.isEmpty, let reread = try? KurswahlParser.parse(reading.boxes + extra, aspect: reading.aspect) {
                    sheet = KurswahlParser.completeGaps(sheet, extra: reread)
                }
            }
            sheets.append(sheet)
        }
        timings["extraRegions"] = Double(regionsRead)
        let extraDone = clock.now
        var result: Kurswahl? = sheets.isEmpty ? nil : KurswahlParser.merge(sheets)
        let mergeDone = clock.now
        timings["merge"] = seconds(mergeDone - extraDone)

        if result == nil, let image = images.first, let boxes = shots.first?.boxes, clock.now < deadline {
            // no photo showed a table: once more with the contrast stretched, then straightened
            let aspect = Double(image.height) / Double(max(1, image.width))
            if let detail = try? await contrastDetail(image, boxes: boxes, aspect: aspect, deadline: deadline) {
                result = detail.kurswahl
            } else if clock.now < deadline, let angle = tilt(nil, boxes: boxes, aspect: aspect), abs(angle) > 0.4 * .pi / 180,
                      let straight = rotated(image, by: angle),
                      let straightBoxes = try? await tableBoxes(straight),
                      let detail = try? KurswahlParser.parseDetailed(straightBoxes, aspect: aspect) {
                result = detail.kurswahl
            }
        }
        guard var result else { throw firstError ?? KurswahlParser.Failure.noSubjects }
        // the reading as the scanner always made it, for the plan to fall back on
        let originalSheets = shots.compactMap { try? KurswahlParser.parseDetailed($0.boxes, aspect: $0.aspect, enhanced: false).kurswahl }
        if !originalSheets.isEmpty {
            let original = KurswahlParser.merge(originalSheets, guards: false)
            if original != result { result.original = [original] }
        }
        let end = clock.now
        timings["first"] = seconds(firstDone - start)
        timings["extra"] = seconds(extraDone - firstDone)
        timings["total"] = seconds(end - start)
        return Result(kurswahl: result, boxes: shots.first?.boxes ?? [],
                      aspect: shots.first?.aspect ?? 4.0 / 3.0, shots: shots, seconds: timings)
    }

    /// The first reading: the whole photo, then the table in two overlapping enlarged halves.
    static func tableBoxes(_ image: CGImage) async throws -> [TextBox] {
        let full = try await recognize(image, region: CGRect(x: 0, y: 0, width: 1, height: 1))
        var boxes = full
        if let table = tableRegion(full) {
            // the table in two overlapping halves, each enlarged more than the whole table could be:
            // the bracketed course numbers are only ~2 mm tall on the sheet
            let upper = CGRect(x: table.minX, y: table.minY, width: table.width, height: table.height * 0.56)
            let lower = CGRect(x: table.minX, y: table.minY + table.height * 0.44, width: table.width, height: table.height * 0.56)
            boxes += try await recognize(image, region: upper)
            boxes += try await recognize(image, region: lower)
        }
        return boxes
    }

    /// Regions read again per photo at most (each is recognised twice, plain and with the contrast stretched).
    static let maxRegions = 6

    /// Where a second, enlarged reading is worth it after `KurswahlParser.parseDetailed` (the same regions as on
    /// Android): the sums row when a sum is missing, the row of every subject required in all four Halbjahre whose
    /// cells were not all read (Sport's plain "2" is the value recognition misses most) first among the rows, rows
    /// with a value that was found but not readable, and Halbjahr columns read in fewer than 80 % of the table rows.
    /// Row bands run from the subject to past the fourth Halbjahr column and follow the tilt of the sums row.
    static func recheckRegions(_ detail: KurswahlParser.Detail) -> [CGRect] {
        func median(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            let sorted = values.sorted(), mid = sorted.count / 2
            return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
        }
        func differences(_ values: [Double]) -> [Double] {
            values.count < 2 ? [] : (1..<values.count).map { values[$0] - values[$0 - 1] }
        }
        let subjects = detail.subjectBoxes.sorted { $0.midY < $1.midY }
        guard subjects.count >= 2, let firstRow = subjects.first, let lastRow = subjects.last else { return [] }
        let diffs = differences(subjects.map(\.midY))
        guard let typical = median(diffs), let subjectX = median(subjects.map(\.midX)) else { return [] }
        let pitch = median(diffs.filter { $0 < typical * 1.5 }) ?? typical

        let columns: [Double]
        let slope: Double
        if detail.sumBoxes.count == 4 {
            columns = detail.sumBoxes.map(\.midX)
            let first = detail.sumBoxes[0], last = detail.sumBoxes[3]
            slope = last.midX != first.midX ? (last.midY - first.midY) / (last.midX - first.midX) : 0
        } else {
            // too few sums: the columns from where the cells were read (0.06 of the width apart when only one was)
            let read = detail.cellBoxes.enumerated().compactMap { h, boxes in median(boxes.map(\.midX)).map { (h, $0) } }
            guard let first = read.first else { return [] }
            let spacing = median(zip(read, read.dropFirst()).map { a, b in (b.1 - a.1) / Double(b.0 - a.0) }) ?? 0.06
            columns = (0..<4).map { first.1 + Double($0 - first.0) * spacing }
            slope = 0
        }
        let spacing = median(differences(columns)) ?? 0.06
        let right = min(1, columns[3] + spacing * 0.6)
        func y(_ atY: Double, _ atX: Double, _ x: Double) -> Double { atY + slope * (x - atX) }
        func region(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double) -> CGRect {
            let l = max(0, left), t = max(0, top)
            return CGRect(x: l, y: t, width: min(1, right) - l, height: min(1, bottom) - t)
        }

        var regions: [CGRect] = []
        if detail.kurswahl.sums.contains(where: { $0 == nil }) {
            let top = min(y(lastRow.midY, lastRow.midX, columns[0]), y(lastRow.midY, lastRow.midX, columns[3])) + pitch * 0.5
            regions.append(region(columns[0] - spacing * 1.5, top, right, top + pitch * 7))
        }
        var rowBands: [CGRect] = []
        for row in detail.kurswahl.rows {
            let required = KurswahlParser.allFourHalves.contains(row.subject) && row.halves.contains { !$0.taken || $0.inferred == true }
            let unreadable = row.halves.contains { $0.unreadable && $0.raw != nil }
            guard required || unreadable,
                  let box = subjects.first(where: { $0.text.caseInsensitiveCompare(row.subject) == .orderedSame }) else { continue }
            let left = box.x - 0.01
            let yLeft = y(box.midY, box.midX, left), yRight = y(box.midY, box.midX, right)
            let band = region(left, min(yLeft, yRight) - pitch * 1.1, right, max(yLeft, yRight) + pitch * 1.1)
            // required subjects first: that is where a gap costs the most
            if required { rowBands.insert(band, at: 0) } else { rowBands.append(band) }
        }
        regions += rowBands
        for (h, x) in columns.enumerated() {
            let read = h < detail.readCells.count ? detail.readCells[h] : 0
            guard Double(read) < Double(detail.tableRows) * 0.8 else { continue }
            let top = min(y(firstRow.midY, firstRow.midX, x), y(firstRow.midY, subjectX, x)) - pitch
            let bottom = y(lastRow.midY, lastRow.midX, x) + pitch
            regions.append(region(x - spacing * 0.55, top, x + spacing * 0.55, bottom))
        }
        var seen = Set<[Int]>()
        return Array(regions.filter { $0.width > 0.01 && $0.height > 0.005 }
            .filter { seen.insert([$0.minX, $0.minY, $0.maxX, $0.maxY].map { Int($0 * 200) }).inserted }
            .prefix(maxRegions))
    }

    /// The photo read again with the contrast stretched, in four overlapping enlarged quarters:
    /// for a dim, blurred or small photo whose first reading found no table.
    static func contrastDetail(_ image: CGImage, boxes: [TextBox], aspect: Double,
                               deadline: ContinuousClock.Instant) async throws -> KurswahlParser.Detail {
        var all = boxes
        let options = PassOptions(contrast: true, maxScale: 4)
        for (x, y) in [(0.0, 0.0), (0.45, 0.0), (0.0, 0.45), (0.45, 0.45)] {
            guard ContinuousClock.now < deadline else { break }
            all += await recognizeClamped(image, region: CGRect(x: x, y: y, width: 0.55, height: 0.55), options: options, deadline: deadline)
        }
        return try KurswahlParser.parseDetailed(all, aspect: aspect)
    }

    /// An extra region: empty on failure, and given up (not waited for) half a second after `deadline`.
    private static func recognizeClamped(_ image: CGImage, region: CGRect, options: PassOptions,
                                         deadline: ContinuousClock.Instant) async -> [TextBox] {
        let clamped = region.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clamped.isNull, clamped.width > 0.005, clamped.height > 0.005 else { return [] }
        let limit = min(.seconds(3), ContinuousClock.now.duration(to: deadline) + .milliseconds(500))
        return (try? await recognize(image, region: clamped, options: options, timeout: limit)) ?? []
    }

    struct Timeout: Error {}

    /// The value of `work`, or `Timeout` once `limit` passed; the work is cancelled and no longer waited for.
    static func withTimeout<T: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        let once = ResumeOnce<T>()
        return try await withCheckedThrowingContinuation { continuation in
            once.set(continuation)
            let worker = Task {
                do { once.resume(with: .success(try await work())) } catch { once.resume(with: .failure(error)) }
            }
            Task {
                try? await Task.sleep(for: limit)
                if once.resume(with: .failure(Timeout())) { worker.cancel() }
            }
        }
    }

    /// The photo's tilt in radians, clockwise positive: from the sums row when the table was read,
    /// otherwise from the subject column.
    static func tilt(_ detail: KurswahlParser.Detail?, boxes: [TextBox], aspect: Double) -> Double? {
        if let slope = detail?.grid?.slope, slope != 0 { return atan(slope * aspect) }
        let keys = Set(SchoolReference.subjects.map { $0.key.lowercased() })
        let subjects = boxes.filter { keys.contains($0.text.lowercased()) }
        guard subjects.count >= 5, let columnX = subjects.map(\.midX).sorted().dropFirst(subjects.count / 2).first else { return nil }
        let column = subjects.filter { abs($0.midX - columnX) < 0.05 }
        guard column.count >= 5 else { return nil }
        let meanX = column.map(\.midX).reduce(0, +) / Double(column.count)
        let meanY = column.map(\.midY).reduce(0, +) / Double(column.count)
        let variance = column.reduce(0) { $0 + ($1.midY - meanY) * ($1.midY - meanY) }
        guard variance > 0 else { return nil }
        let dxdy = column.reduce(0) { $0 + ($1.midX - meanX) * ($1.midY - meanY) } / variance
        return atan(-dxdy / aspect)
    }

    /// The image turned by `angle` radians counterclockwise around its centre, same size.
    static func rotated(_ image: CGImage, by angle: Double) -> CGImage? {
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        context.rotate(by: angle)
        context.translateBy(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// How an extra recognition pass reads its region.
    public struct PassOptions: Sendable {
        /// Grayscale with the contrast stretched: faint print, dim light and glare.
        public var contrast: Bool
        /// Largest enlargement of the crop.
        public var maxScale: Double

        public init(contrast: Bool = false, maxScale: Double = 3) {
            self.contrast = contrast
            self.maxScale = maxScale
        }
    }

    /// Recognised text of a region (0…1, origin top-left), mapped back to whole-image coordinates.
    /// Throws `Timeout` when recognition takes longer than `timeout`, so a scan never hangs.
    public static func recognize(_ image: CGImage, region: CGRect, options: PassOptions = .init(),
                                 timeout: Duration = .seconds(15)) async throws -> [TextBox] {
        let pixel = CGRect(x: region.minX * CGFloat(image.width), y: region.minY * CGFloat(image.height),
                           width: region.width * CGFloat(image.width), height: region.height * CGFloat(image.height))
            .integral
        guard let cropped = image.cropping(to: pixel) else { return [] }
        // enlarge small crops so a 2 mm digit is ~40 px tall; cap the size for memory
        let scale = min(options.maxScale, 3600.0 / Double(max(cropped.width, cropped.height)))
        var input = scale > 1.2 ? (resized(cropped, scale: scale) ?? cropped) : cropped
        if options.contrast { input = stretched(input) ?? input }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = [Locale.Language(identifier: "de-DE")]
        let configured = request, source = input
        let observations = try await withTimeout(timeout) { try await configured.perform(on: source) }
        return observations.compactMap { observation -> TextBox? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let b = observation.boundingBox.cgRect // 0…1 of the crop, origin bottom-left
            return TextBox(text: candidate.string,
                           x: region.minX + b.minX * region.width,
                           y: region.minY + (1 - b.maxY) * region.height,
                           width: b.width * region.width,
                           height: b.height * region.height,
                           confidence: Double(candidate.confidence))
        }
    }

    /// From the subject column to past the fourth Halbjahr column, first subject to "Summen".
    static func tableRegion(_ boxes: [TextBox]) -> CGRect? {
        let keys = Set(SchoolReference.subjects.map { $0.key.lowercased() })
        let subjects = boxes.filter { keys.contains($0.text.lowercased()) }
        guard subjects.count >= 5, let columnX = subjects.map(\.midX).sorted().dropFirst(subjects.count / 2).first else { return nil }
        let column = subjects.filter { abs($0.midX - columnX) < 0.05 }
        guard let top = column.map(\.minYValue).min() else { return nil }
        let summen = boxes.first { $0.text.lowercased().hasPrefix("summen") }
        let bottom = max(summen?.maxY ?? 0, column.map(\.maxY).max() ?? 0) + 0.03
        let left = max(0, columnX - 0.06)
        let right = min(1, columnX + 0.56)
        let y0 = max(0, top - 0.03)
        return CGRect(x: left, y: y0, width: right - left, height: min(1, bottom) - y0)
    }

    private static func resized(_ image: CGImage, scale: Double) -> CGImage? {
        let width = Int(Double(image.width) * scale), height = Int(Double(image.height) * scale)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Grayscale, the darkest 1 % mapped to black and the brightest 5 % to white.
    static func stretched(_ image: CGImage) -> CGImage? {
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let data = context.data else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height)
        var histogram = [Int](repeating: 0, count: 256)
        for i in 0..<(width * height) { histogram[Int(pixels[i])] += 1 }
        func percentile(_ p: Double) -> Int {
            let target = Int(Double(width * height) * p)
            var sum = 0
            for (value, count) in histogram.enumerated() {
                sum += count
                if sum > target { return value }
            }
            return 255
        }
        let low = percentile(0.01), high = max(low + 16, percentile(0.95))
        let table = (0..<256).map { v in UInt8(max(0, min(255, (v - low) * 255 / (high - low)))) }
        for i in 0..<(width * height) { pixels[i] = table[Int(pixels[i])] }
        return context.makeImage()
    }
}

/// Resumes a continuation exactly once, from whichever task gets there first.
private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?

    /// Called before either task starts.
    func set(_ continuation: CheckedContinuation<T, any Error>) {
        lock.lock()
        defer { lock.unlock() }
        self.continuation = continuation
    }

    /// True when this call resumed it.
    @discardableResult
    func resume(with result: Swift.Result<T, any Error>) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let continuation else { return false }
        self.continuation = nil
        continuation.resume(with: result)
        return true
    }
}

private extension TextBox {
    var minYValue: Double { y }
}
