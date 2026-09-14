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

        public init(kurswahl: Kurswahl, boxes: [TextBox], aspect: Double, shots: [Shot]? = nil) {
            self.kurswahl = kurswahl
            self.boxes = boxes
            self.aspect = aspect
            self.shots = shots
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

    /// Several photos of one sheet (overview and close-ups): each read on its own, then merged cell by cell.
    public static func read(_ images: [CGImage]) async throws -> Result {
        var shots: [Shot] = []
        var sheets: [Kurswahl] = []
        var firstError: (any Error)?
        for image in images {
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
            let aspect = Double(image.height) / Double(max(1, image.width))
            shots.append(Shot(boxes: boxes, aspect: aspect))
            do {
                sheets.append(try KurswahlParser.parse(boxes, aspect: aspect))
            } catch {
                firstError = firstError ?? error
            }
        }
        guard !sheets.isEmpty else { throw firstError ?? KurswahlParser.Failure.noSubjects }
        return Result(kurswahl: KurswahlParser.merge(sheets), boxes: shots.first?.boxes ?? [],
                      aspect: shots.first?.aspect ?? 4.0 / 3.0, shots: shots)
    }

    /// Recognised text of a region (0…1, origin top-left), mapped back to whole-image coordinates.
    public static func recognize(_ image: CGImage, region: CGRect) async throws -> [TextBox] {
        let pixel = CGRect(x: region.minX * CGFloat(image.width), y: region.minY * CGFloat(image.height),
                           width: region.width * CGFloat(image.width), height: region.height * CGFloat(image.height))
            .integral
        guard let cropped = image.cropping(to: pixel) else { return [] }
        // enlarge small crops so a 2 mm digit is ~40 px tall; cap the size for memory
        let scale = min(3.0, 3600.0 / Double(max(cropped.width, cropped.height)))
        let input = scale > 1.2 ? (resized(cropped, scale: scale) ?? cropped) : cropped

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = [Locale.Language(identifier: "de-DE")]
        let observations = try await request.perform(on: input)
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
}

private extension TextBox {
    var minYValue: Double { y }
}
