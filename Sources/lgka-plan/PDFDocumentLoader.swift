import Foundation
import PDFKit

enum PDFDocumentLoader {
    static func page(_ path: String) -> PDFPage? {
        PDFDocument(url: URL(fileURLWithPath: path))?.page(at: 0)
    }
}
