import Foundation
import LGKACore

/// The app's single data source: https://api.lgka.app (github.com/lgka-app/api).
/// The Worker mirrors and parses the school's PDFs and pages; the app only
/// syncs hashes and renders. Credentials are the user's school login (Keychain).
enum SchoolAPI {
    /// Same User-Agent format the Flutter app sends (app_info.dart).
    static let userAgent = "LGKA-App-Luka-Loehr/" +
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0")

    static let host = "lessing-gymnasium-karlsruhe.de"

    /// The in-app browser still answers the school website's own Basic Auth
    /// challenge with the stored login (links from news lead there).
    static func isSchoolHost(_ host: String?) -> Bool {
        guard let host else { return false }
        return host == Self.host || host.hasSuffix("." + Self.host)
    }

    static let client = APIClient(userAgent: userAgent) {
        Credentials.load().map { SchoolCredentials(user: $0.user, password: $0.password) }
    }

    static let store = SyncStore()

    /// Login gate: the typed pair is checked by the API (`/v1/auth/check`), never
    /// against a string in the app. `false` = wrong credentials.
    static func verify(_ pair: Credentials.Pair) async throws -> Bool {
        try await client.check(SchoolCredentials(user: pair.user, password: pair.password))
    }
}
