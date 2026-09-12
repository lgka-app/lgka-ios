import Foundation

/// Typed failures of the verified data layer. Every parser throws one of
/// these instead of trapping, so a malformed server response degrades to an
/// error state in the UI (and to a stale-cache fallback) rather than a crash.
public enum LGKAError: Error, Sendable, Equatable {
    /// The payload was not the JSON shape the parser expects.
    case invalidJSON(String)
    /// A required field was missing or `null`.
    case missingField(String)
    /// The Untis table header did not have the expected number of columns.
    case unexpectedTableHeader(found: Int, expected: Int)
    /// The schedule page did not contain the `#mod-custom213` module.
    case scheduleModuleMissing
    /// The schedule page contained no timetable links.
    case noSchedulesFound
    /// PDFKit could not open the document or its first page.
    case pdfUnreadable
    /// An HTML element could not be cloned for serialization.
    case htmlCloneFailed
}

extension LGKAError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let detail): return "Invalid JSON: \(detail)"
        case .missingField(let name): return "Missing field: \(name)"
        case .unexpectedTableHeader(let found, let expected):
            return "Unexpected substitution table header: \(found) columns, expected \(expected)"
        case .scheduleModuleMissing: return "Schedule module not found on page"
        case .noSchedulesFound: return "No schedules found on page"
        case .pdfUnreadable: return "PDF could not be read"
        case .htmlCloneFailed: return "HTML element could not be cloned"
        }
    }
}
