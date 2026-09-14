import Foundation

// Wire models of https://api.lgka.app (github.com/lgka-app/api). The app no
// longer parses anything itself: every screen renders these as decoded.

// MARK: - Resources

public enum Resource: String, CaseIterable, Sendable, Codable {
    case substitutions, schedules, news, events, weather
    /// The school's public staff list (Untis code → name, subjects, role). Opt-in on `/v1/sync`:
    /// the API only includes it when the query names it, which this client always does.
    case kollegium
}

// MARK: - Mirrored PDFs

public struct PdfRef: Codable, Hashable, Sendable {
    /// API path, e.g. "/v1/files/<sha256>.pdf".
    public var url: String
    public var sha256: String
    public var bytes: Int
    public var pageCount: Int
    public var sourceLastModified: String?
    /// Present only when the client asked for `embed=pdf`; the sync store
    /// writes it to disk and drops it from the persisted JSON.
    public var base64: String?
}
