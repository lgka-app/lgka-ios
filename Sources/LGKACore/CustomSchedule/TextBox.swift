import Foundation

/// A piece of text with its box, origin top-left. From a PDF (points, `italic` known)
/// or from text recognition on a photo (0…1 of the image, `confidence` known).
public struct TextBox: Codable, Hashable, Sendable {
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    /// Recognition confidence 0…1; nil for PDF text.
    public var confidence: Double?
    /// Set for PDF text: the glyphs are set in an italic face (Untis prints rooms in italics).
    public var italic: Bool?

    public init(text: String, x: Double, y: Double, width: Double, height: Double,
                confidence: Double? = nil, italic: Bool? = nil) {
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.confidence = confidence
        self.italic = italic
    }

    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }

    /// Splits a multi-word box into one box per word, spreading the width by character count
    /// (text recognition sometimes returns "3 3 3" across three table columns as one line).
    public func words() -> [TextBox] {
        let parts = text.split(whereSeparator: \.isWhitespace)
        guard parts.count > 1 else { return [self] }
        let total = Double(text.count)
        var result: [TextBox] = []
        var offset = 0
        let chars = Array(text)
        for part in parts {
            // position of this part in the original string
            while offset < chars.count, chars[offset].isWhitespace { offset += 1 }
            let start = Double(offset), length = Double(part.count)
            result.append(TextBox(text: String(part),
                                  x: x + width * start / total, y: y,
                                  width: width * length / total, height: height,
                                  confidence: confidence, italic: italic))
            offset += part.count
        }
        return result
    }
}

extension Array where Element == Double {
    /// Median of the values; nil when empty.
    var median: Double? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
