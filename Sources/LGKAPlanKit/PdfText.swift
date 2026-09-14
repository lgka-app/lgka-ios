import Foundation
import PDFKit
import LGKACore

/// Positioned words of a PDF page for `StufenplanParser` (points, origin top-left).
public enum PdfText {
    public static func words(in page: PDFPage) -> [TextBox] {
        guard let string = page.string, !string.isEmpty,
              let regex = try? NSRegularExpression(pattern: #"\S+"#) else { return [] }
        let media = page.bounds(for: .mediaBox)
        let ns = string as NSString
        let attributed = page.attributedString
        let fontsMatch = attributed?.length == ns.length
        var words: [TextBox] = []
        for match in regex.matches(in: string, range: NSRange(location: 0, length: ns.length)) {
            // PDFKit's own string ↔ glyph mapping; per-character bounds drift on these Untis exports
            guard let selection = page.selection(for: match.range) else { continue }
            let r = selection.bounds(for: page)
            var italic: Bool?
            if fontsMatch, let attributed {
                let font = attributed.attribute(.font, at: match.range.location, effectiveRange: nil)
                let fontName = (font as AnyObject?)?.value(forKey: "fontName") as? String ?? ""
                italic = fontName.contains("Italic") || fontName.contains("Oblique")
            }
            words.append(TextBox(text: ns.substring(with: match.range),
                                 x: r.minX - media.minX, y: media.maxY - r.maxY,
                                 width: r.width, height: r.height, italic: italic))
        }
        return words
    }

    /// The Stufenplan on the first page of a PDF file.
    public static func stufenplan(at url: URL) throws -> Stufenplan {
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try StufenplanParser.parse(words(in: page))
    }
}
