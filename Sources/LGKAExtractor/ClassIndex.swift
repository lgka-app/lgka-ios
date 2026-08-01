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
func buildClassIndex(url: URL) -> [String: Int]? {
    guard let doc = PDFDocument(url: url) else { return nil }
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
