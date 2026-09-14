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
        let sheets = readings.map(\.detail.kurswahl)
        var result: Kurswahl? = sheets.isEmpty ? nil
            : sheets.count > 1 ? KurswahlParser.repairWithSums(KurswahlParser.merge(sheets)) : sheets[0]
        let mergeDone = clock.now
        timings["merge"] = seconds(mergeDone - firstDone)
        timings["extraRegions"] = 0

        if let merged = result, !KurswahlParser.isComplete(merged), clock.now < deadline,
           let best = readings.max(by: { KurswahlParser.consistency($0.detail.kurswahl) < KurswahlParser.consistency($1.detail.kurswahl) }) {
            let (filled, regionsRead) = await refill(merged, image: best.image, boxes: best.boxes, detail: best.detail,
                                                     aspect: best.aspect, deadline: deadline)
            timings["extraRegions"] = Double(regionsRead)
            if acceptsRefill(merged, filled) { result = filled }
        }

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
        timings["extra"] = seconds(end - mergeDone)
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

    /// Whether a reading with gaps filled replaces the merged one: every sum stays, no cell became
    /// inferred and no unnamed row appeared, and either more Halbjahre now add up to their sums or
    /// every change only confirms what was there (an inferred value read, a course number added).
    static func acceptsRefill(_ merged: Kurswahl, _ filled: Kurswahl) -> Bool {
        guard zip(merged.sums, filled.sums).allSatisfy({ $0 == nil || $0 == $1 }) else { return false }
        func inferred(_ k: Kurswahl) -> Int { k.rows.reduce(0) { $0 + $1.halves.filter { $0.inferred == true }.count } }
        func unnamed(_ k: Kurswahl) -> Int { k.rows.filter { $0.subject == "?" }.count }
        guard inferred(filled) <= inferred(merged), unnamed(filled) <= unnamed(merged) else { return false }
        if KurswahlParser.matchedSums(filled) > KurswahlParser.matchedSums(merged) { return true }
        // the same rows, an unnamed one possibly named now
        guard KurswahlParser.matchedSums(filled) == KurswahlParser.matchedSums(merged),
              filled.rows.count == merged.rows.count,
              zip(merged.rows, filled.rows).allSatisfy({ $0.subject == $1.subject || $0.subject == "?" }) else { return false }
        return zip(merged.rows, filled.rows).allSatisfy { before, after in
            zip(before.halves, after.halves).allSatisfy { $0.hours == $1.hours }
        }
    }

    /// Most extra regions read for one scan.
    static let maxRegions = 6

    /// The merged reading's gaps read again on one photo, each region enlarged up to 8× with the
    /// contrast stretched. Lone digits such as Sport's "2" are dropped when the whole table is read,
    /// but a row alone is read reliably. Regions, most important first, at most `maxRegions`, none
    /// started after `deadline`: rows of required subjects (D, M, G, Sport) with an unread cell,
    /// the sums row when a sum is missing, rows unread in a Halbjahr whose sum does not match, other
    /// rows with an unread cell. The result is `merged` with gaps filled (`KurswahlParser.fillGaps`),
    /// never a changed value, then `repairWithSums`.
    /// Also returns how many regions were read.
    static func refill(_ merged: Kurswahl, image: CGImage, boxes: [TextBox], detail: KurswahlParser.Detail,
                       aspect: Double, deadline: ContinuousClock.Instant) async -> (Kurswahl, Int) {
        guard let grid = detail.grid, grid.columnXs.count == 6, !grid.rows.isEmpty else { return (merged, 0) }
        let pitch = grid.pitch, spacing = grid.spacing
        let x0 = grid.columnXs[0] - spacing * 0.6, x1 = grid.columnXs[5] + spacing * 0.6
        let unmatched = Set((0..<min(4, merged.sums.count)).filter { h in
            merged.sums[h].map { sum in merged.rows.reduce(0) { $0 + (h < $1.halves.count ? $1.halves[h].hours ?? 0 : 0) } != sum } ?? true
        })
        var ranked: [(priority: Int, region: CGRect)] = []
        for gridRow in grid.rows {
            guard let subject = gridRow.subject, let row = merged.rows.first(where: { $0.subject == subject }), row.halves.count == 4 else { continue }
            let open = (0..<4).filter { h in
                let cell = row.halves[h]
                return cell.inferred == true || (!cell.taken && (cell.raw == nil || cell.unreadable))
            }
            let required = KurswahlParser.allFourHalves.contains(subject)
            guard !open.isEmpty, required || row.halves.contains(where: { $0.taken && $0.inferred != true }) else { continue }
            guard let top = gridRow.ys.min(), let bottom = gridRow.ys.max() else { continue }
            let priority = required ? 0 : open.contains(where: unmatched.contains) ? 2 : 3
            ranked.append((priority, CGRect(x: x0, y: top - pitch * 0.9, width: x1 - x0, height: bottom - top + pitch * 1.8)))
        }
        if merged.rows.contains(where: { $0.subject == "?" }), let top = grid.rows.map(\.subjectY).min(), let bottom = grid.rows.map(\.subjectY).max() {
            // unnamed rows: single-letter subjects ("D", "E") are dropped when the whole sheet is read but
            // read in the subject column alone; two overlapping halves, first
            let middle = (top + bottom) / 2
            for (y0, y1) in [(top - pitch, middle + pitch), (middle - pitch, bottom + pitch)] {
                ranked.append((-1, CGRect(x: grid.subjectX - spacing * 0.6, y: y0, width: spacing * 1.2, height: y1 - y0)))
            }
        }
        if merged.sums.contains(where: { $0 == nil }) {
            let y = grid.bottom
            ranked.append((1, CGRect(x: grid.columnXs[2] - spacing, y: y - pitch * 1.2, width: spacing * 5, height: pitch * 2.4)))
        }
        let regions = ranked.enumerated().sorted { ($0.element.priority, $0.offset) < ($1.element.priority, $1.offset) }
            .prefix(maxRegions).map(\.element.region)
        guard !regions.isEmpty else { return (merged, 0) }

        let options = PassOptions(contrast: true, maxScale: 8)
        var extra: [TextBox] = []
        var read = 0
        for region in regions {
            guard ContinuousClock.now < deadline else { break }
            extra += await recognizeClamped(image, region: region, options: options, deadline: deadline)
            read += 1
        }
        guard !extra.isEmpty, let reread = try? KurswahlParser.parseDetailed(boxes + extra, aspect: aspect) else { return (merged, read) }
        return (KurswahlParser.repairWithSums(KurswahlParser.fillGaps(merged, from: reread.kurswahl)), read)
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
