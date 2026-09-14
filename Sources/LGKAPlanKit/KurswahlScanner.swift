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
    public struct Result: Sendable {
        public var kurswahl: Kurswahl
        /// Every recognised box of both passes, 0…1 of the whole image.
        public var boxes: [TextBox]
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
        let full = try await recognize(image, region: CGRect(x: 0, y: 0, width: 1, height: 1))
        var boxes = full
        if let table = tableRegion(full) {
            boxes += try await recognize(image, region: table)
        }
        return Result(kurswahl: try KurswahlParser.parse(boxes), boxes: boxes)
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
