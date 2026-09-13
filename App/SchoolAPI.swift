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

// ── WMO helpers (UI layer, mirrors the app's WmoUtils) ─────────────────────

enum Wmo {
    static func symbol(_ code: Int, isDay: Bool) -> String {
        switch code {
        case 0, 1: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 80, 81: return "cloud.rain.fill"
        case 65, 82: return "cloud.heavyrain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    /// Localized description (String Catalog keys `wmo.<code>`).
    static func description(_ code: Int) -> String {
        let known: Set<Int> = [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67,
                               71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]
        return L.s(known.contains(code) ? "wmo.\(code)" : "wmo.unknown")
    }
}

/// Calendar-day helpers replacing ad-hoc DateFormatters in view bodies.
enum LocalDate {
    static var calendar: Calendar { Calendar.current }

    /// "yyyy-MM-dd" -> Date at local midnight, nil if malformed.
    static func parse(_ iso: String) -> Date? {
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: d))
    }

    static func isToday(_ iso: String) -> Bool {
        guard let date = parse(iso) else { return false }
        return calendar.isDateInToday(date)
    }
}
