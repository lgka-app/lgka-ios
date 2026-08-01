import Foundation
import PDFKit

/// PDF-library boundary: turns page 0 into geometric words grouped into
/// visual lines. Everything past this file is library-agnostic — identical
/// on iOS.
///
/// PDFKit quirk: `characterBounds(at:)` returns TIGHT glyph bounds, so the
/// top of "L" and "e" in the same word differ by the x-height delta —
/// clustering lines from glyph tops shreds every line into height classes.
/// Instead, PDFKit's own `selectionsByLine()` provides the visual line
/// bands; glyphs are bucketed into the band containing their y-center.
/// Glyph x-coordinates are reliable and drive word/column geometry.
struct Word {
    let text: String
    let left: Double
    let right: Double
}

struct Line {
    let top: Double
    let words: [Word]
    /// Words joined with single spaces — used for anchor/regex matching.
    var text: String { words.map(\.text).joined(separator: " ") }
}

/// x-gap above which two glyphs are separate words (whitespace also splits).
private let wordGap = 3.0

func extractLines(from url: URL) -> [Line]? {
    guard let doc = PDFDocument(url: url), let page = doc.page(at: 0),
          let pageString = page.string else { return nil }

    let pageHeight = page.bounds(for: .mediaBox).height
    let ns = pageString as NSString

    // Visual line bands from PDFKit itself (in PDF coords, y grows upward).
    guard let all = page.selection(for: NSRange(location: 0, length: ns.length))
    else { return nil }
    let bands: [(minY: Double, maxY: Double)] = all.selectionsByLine()
        .compactMap { sel in
            let b = sel.bounds(for: page)
            return b.isEmpty ? nil : (Double(b.minY), Double(b.maxY))
        }
        .sorted { $0.maxY > $1.maxY } // top of page first

    func bandIndex(forMidY midY: Double) -> Int? {
        // containing band, else nearest by center distance
        if let i = bands.firstIndex(where: { midY >= $0.minY && midY <= $0.maxY }) {
            return i
        }
        return bands.indices.min(by: {
            abs((bands[$0].minY + bands[$0].maxY) / 2 - midY) <
                abs((bands[$1].minY + bands[$1].maxY) / 2 - midY)
        })
    }

    struct Glyph {
        let text: String
        let left: Double
        let right: Double
    }
    // PDFKit off-by-N quirk: page.string contains "\n" between lines, but
    // characterBounds(at:) indexes the text WITHOUT those newlines — each
    // newline shifts the mapping by one. Track the bounds index separately.
    var perBand: [[Glyph]] = Array(repeating: [], count: bands.count)
    var boundsIdx = 0
    for i in 0..<ns.length {
        let ch = ns.substring(with: NSRange(location: i, length: 1))
        if ch == "\n" || ch == "\r" { continue }
        let r = page.characterBounds(at: boundsIdx)
        boundsIdx += 1
        if r.isEmpty { continue }
        guard let band = bandIndex(forMidY: r.midY) else { continue }
        perBand[band].append(Glyph(text: ch, left: r.minX, right: r.maxX))
    }

    // Within each band: sort by x, split into words on whitespace or gap.
    return perBand.enumerated().compactMap { bandIdx, glyphs in
        var words: [Word] = []
        var text = ""
        var left = 0.0
        var right = 0.0
        func flush() {
            if !text.isEmpty {
                words.append(Word(text: text, left: left, right: right))
                text = ""
            }
        }
        for g in glyphs.sorted(by: { $0.left < $1.left }) {
            if g.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                flush()
                continue
            }
            if !text.isEmpty && g.left - right > wordGap { flush() }
            if text.isEmpty { left = g.left }
            text += g.text
            right = g.right
        }
        flush()
        if words.isEmpty { return nil }
        return Line(top: pageHeight - bands[bandIdx].maxY, words: words)
    }
}
