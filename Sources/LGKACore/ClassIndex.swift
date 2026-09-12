import Foundation
import PDFKit

/// Schedule (Stundenplan) class-to-page index — Swift port of the app's
/// `_buildClassIndexInIsolate` (schedule_provider.dart), verified against
/// the class_index goldens in lgka-app/verification.
///
/// Contract: scan each page's lowercased text for classes 5a-10e; the first
/// page containing the class string wins; the stored page number is
/// zero-based pageIndex + 2 (1-based + cover offset, matching the app's PDF
/// viewer navigation). j11/j12 are NOT parsed — the app hardcodes
/// {j11: 2, j12: 3} for the J11/J12 PDF.
public func buildClassIndex(url: URL) throws -> [String: Int] {
    guard let doc = PDFDocument(url: url) else { throw LGKAError.pdfUnreadable }
    var classes: [String] = []
    for grade in 5...10 {
        for letter in "abcde" { classes.append("\(grade)\(letter)") }
    }
    var index: [String: Int] = [:]
    for pageIndex in 0..<doc.pageCount {
        guard let text = doc.page(at: pageIndex)?.string?.lowercased() else { continue }
        for c in classes where index[c] == nil && text.contains(c) {
            index[c] = pageIndex + 2
        }
    }
    return index
}

/// Jahrgang-to-page index: every page whose text carries a "J11"/"J12"/"J13"… header
/// (Untis prints the Jahrgang where class pages print "5b"). Same page contract as
/// `buildClassIndex`; the first page wins. Discovered, never hardcoded, so a split
/// "J11" upload or a future J13 needs no app update.
public func buildJahrgangIndex(url: URL) throws -> [String: Int] {
    guard let doc = PDFDocument(url: url) else { throw LGKAError.pdfUnreadable }
    var index: [String: Int] = [:]
    for pageIndex in 0..<doc.pageCount {
        guard let text = doc.page(at: pageIndex)?.string?.lowercased() else { continue }
        for m in text.matches(of: #/\bj(1\d)\b/#) {
            let key = "j\(m.1)"
            if index[key] == nil { index[key] = pageIndex + 2 }
        }
    }
    return index
}

/// Lowercased text of every page — used by the PDF viewer's search.
public func pageTexts(url: URL) throws -> [String] {
    guard let doc = PDFDocument(url: url) else { throw LGKAError.pdfUnreadable }
    return (0..<doc.pageCount).map { doc.page(at: $0)?.string?.lowercased() ?? "" }
}
