import PDFKit

/// Debug builds only: `LGKA_DEBUG_SUB_PAGES=n` pads a substitution PDF to n pages
/// (repeating its own pages) to check how the viewer handles long plans.
enum DebugPdf {
    static func padded(_ file: URL) -> URL {
        #if DEBUG
        guard let n = ProcessInfo.processInfo.environment["LGKA_DEBUG_SUB_PAGES"].flatMap(Int.init), n > 1,
              let doc = PDFDocument(url: file), doc.pageCount > 0 else { return file }
        let out = PDFDocument()
        while out.pageCount < n {
            for i in 0..<doc.pageCount where out.pageCount < n {
                if let page = doc.page(at: i)?.copy() as? PDFPage { out.insert(page, at: out.pageCount) }
            }
        }
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("debug_substitution_\(n)_pages.pdf")
        return out.write(to: dest) ? dest : file
        #else
        return file
        #endif
    }
}
