import Foundation
import PDFKit

/// Diagnostic: raw characterBounds + selectionsByLine band rects.
func import_dump_raw(url: URL) {
    guard let doc = PDFDocument(url: url), let page = doc.page(at: 0),
          let s = page.string else { return }
    let ns = s as NSString
    print("mediaBox: \(page.bounds(for: .mediaBox))")
    if let all = page.selection(for: NSRange(location: 0, length: ns.length)) {
        for (i, sel) in all.selectionsByLine().enumerated() {
            let b = sel.bounds(for: page)
            let txt = (sel.string ?? "").prefix(40)
            print(String(format: "band %2d y=%6.1f..%6.1f x=%6.1f..%6.1f  \"%@\"",
                         i, b.minY, b.maxY, b.minX, b.maxX, String(txt)))
        }
    }
    print("---- first 80 chars ----")
    for i in 0..<min(80, ns.length) {
        let ch = ns.substring(with: NSRange(location: i, length: 1))
            .replacingOccurrences(of: "\n", with: "\\n")
        let r = page.characterBounds(at: i)
        print(String(format: "%3d %@  x=%6.1f..%6.1f y=%6.1f..%6.1f",
                     i, ch == " " ? "␣" : ch, r.minX, r.maxX, r.minY, r.maxY))
    }
}
