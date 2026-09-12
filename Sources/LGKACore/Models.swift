import Foundation

// Wire models of https://api.lgka.app (github.com/lgka-app/api). The app no
// longer parses anything itself: every screen renders these as decoded.

// MARK: - Resources

public enum Resource: String, CaseIterable, Sendable, Codable {
    case substitutions, schedules, news, events, weather
}

// MARK: - Substitutions

public struct SubstitutionsData: Codable, Hashable, Sendable {
    public var today: DayPlan?
    public var tomorrow: DayPlan?

    public init(today: DayPlan? = nil, tomorrow: DayPlan? = nil) {
        self.today = today
        self.tomorrow = tomorrow
    }
}

public struct DayPlan: Codable, Hashable, Sendable {
    /// Upstream file name, e.g. "v_schueler_heute.pdf".
    public var source: String
    public var pdf: PdfRef
    public var sourceLastModified: String?
    public var meta: SubstitutionMeta
    public var plan: SubstitutionPlan
    /// Plain text per page (client-side search).
    public var pages: [String]

    /// The app's display rule (SubstitutionState.canDisplay parity).
    public var canDisplay: Bool {
        !plan.isEmpty && meta.weekday != "weekend" && !meta.weekday.isEmpty && !meta.date.isEmpty
    }
}

public struct SubstitutionMeta: Codable, Hashable, Sendable {
    /// German weekday, or "weekend" for the empty export.
    public var weekday: String
    /// DD.MM.YYYY
    public var date: String
    /// Generation timestamp as printed in the PDF, e.g. "11.9.2026 8:56".
    public var lastUpdated: String
}

public struct SubstitutionPlan: Codable, Hashable, Sendable {
    public var school: String?
    public var address: String?
    public var schoolYear: String?
    public var untisVersion: String?
    public var generatedAt: String?
    public var planDate: String?
    public var weekday: String?
    public var isEmpty: Bool
    public var announcements: [String]
    public var absentTeachers: [String]
    public var absentClasses: [String]
    public var blockedRooms: [String]
    public var entries: [SubstitutionEntry]
    public var footer: SubstitutionFooter?
    public var pageCount: Int

    /// Entries affecting `className` ("6a" matches cells "6a", "6ab", "5c, 6a").
    public func entries(forClass className: String) -> [SubstitutionEntry] {
        let lc = className.lowercased()
        return entries.filter { $0.classes.contains { $0.lowercased() == lc } }
    }
}

public struct SubstitutionEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: String {
        [type, period, classesRaw, substitute, subject, room, originalSubject, originalTeacher, originalRoom, note]
            .map { $0 ?? "" }.joined(separator: "|") + "|\(page)"
    }
    public var type: String?
    public var period: String?
    public var classes: [String]
    public var classesRaw: String?
    public var substitute: String?
    public var subject: String?
    public var room: String?
    public var originalSubject: String?
    public var originalTeacher: String?
    public var originalRoom: String?
    public var note: String?
    /// 0-based page the entry starts on.
    public var page: Int
}

public struct SubstitutionFooter: Codable, Hashable, Sendable {
    public var untisPeriod: Int?
    public var date: String?
    public var calendarWeek: Int?
    public var schoolYearShort: String?
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

// MARK: - Schedules

public struct SchedulesData: Codable, Hashable, Sendable {
    public var items: [ScheduleItem]

    public init(items: [ScheduleItem]) { self.items = items }
}

public struct ScheduleItem: Codable, Hashable, Sendable, Identifiable {
    public var id: String { fullUrl }
    public var title: String
    public var url: String
    public var fullUrl: String
    /// "1. Halbjahr" | "2. Halbjahr" | "Unbekannt"
    public var halbjahr: String
    /// "Klassen 5-10" | "J11" | "J12" | "J11/J12" | "Unbekannt"
    public var gradeLevel: String
    public var available: Bool
    public var pdf: PdfRef?
    /// class → REAL 1-based PDF page ("5a"…"10e", "j11", "j12" where present).
    public var classIndex: [String: Int]
    /// Plain text per page (client-side search).
    public var pages: [String]

    /// Grades this PDF covers, discovered from the link title ("… - 5-10" → 5…10,
    /// "… - J11" → [11], "… - J11/12" → [11, 12]); the API's `gradeLevel` as fallback.
    public var grades: [Int] {
        let fromTitle = ScheduleGrades.fromTitle(title)
        if !fromTitle.isEmpty { return fromTitle }
        switch gradeLevel {
        case "Klassen 5-10": return Array(5...10)
        case "J11": return [11]
        case "J12": return [12]
        case "J11/J12": return [11, 12]
        default: return []
        }
    }

    /// Does this PDF contain `cls` ("10b" → grade 10, "j11" → grade 11)?
    public func covers(_ cls: String) -> Bool {
        guard let grade = ScheduleGrades.gradeOf(cls) else { return false }
        return grades.contains(grade)
    }

    /// 0-based page index for the PDF viewer, or nil when the class is not in this PDF.
    public func pageIndex(forClass cls: String) -> Int? {
        guard let page = classIndex[cls.lowercased()], page >= 1 else { return nil }
        return page - 1
    }
}

// MARK: - News

public struct NewsData: Codable, Hashable, Sendable {
    public var articles: [NewsArticle]

    public init(articles: [NewsArticle]) { self.articles = articles }
}

public struct NewsArticle: Codable, Hashable, Sendable, Identifiable {
    public var id: String { url }
    public var title: String
    public var author: String
    public var description: String
    public var content: String?
    public var htmlContent: String?
    /// As displayed, e.g. "09. September 2026".
    public var createdDate: String
    /// ISO-8601 when known.
    public var publishedAt: String?
    public var views: Int
    public var url: String
    public var links: [NewsLink]
    public var standaloneLinks: [NewsLink]
    public var images: [NewsImage]
    public var downloads: [NewsDownload]
    public var tags: [String]
}

public struct NewsLink: Codable, Hashable, Sendable {
    public var text: String
    public var url: String
}

public struct NewsImage: Codable, Hashable, Sendable {
    public var url: String
    public var thumbnailUrl: String?
    public var alt: String?
}

public struct NewsDownload: Codable, Hashable, Sendable {
    public var title: String
    public var url: String
    public var fileType: String
    public var size: String?
}

// MARK: - Events

public struct EventsData: Codable, Hashable, Sendable {
    public var events: [SchoolEvent]
    public var horizonWeeks: Int

    public init(events: [SchoolEvent], horizonWeeks: Int = 3) {
        self.events = events
        self.horizonWeeks = horizonWeeks
    }
}

public struct SchoolEvent: Codable, Hashable, Sendable, Identifiable {
    public var id: String { "\(date)|\(title)" }
    /// YYYY-MM-DD
    public var date: String
    /// "HH:MM" or nil for all-day events.
    public var time: String?
    public var title: String
}

// MARK: - Weather

public enum WeatherSource: String, Codable, Hashable, Sendable {
    case school
    case openMeteo = "open-meteo"
}

public struct WeatherData: Codable, Hashable, Sendable {
    /// Who provides `current`: the school's rooftop station or Open-Meteo.
    public var source: WeatherSource
    public var timezone: String
    public var current: CurrentWeather
    /// All forecast hours (3 days); window on the client with `hourly(from:)`.
    public var hourly: [HourlyForecast]
    public var daily: [DailyForecast]
    public var station: StationBlock
    public var attribution: [String]

    /// [start of `localNow`'s hour, +24h). `localNow` is "yyyy-MM-ddTHH:mm" Berlin wall clock.
    public func hourly(from localNow: String, hours: Int = 24) -> [HourlyForecast] {
        WeatherWindow.window(hourly, from: localNow, hours: hours)
    }
}

public struct CurrentWeather: Codable, Hashable, Sendable {
    public var temp: Double
    public var feelsLike: Double
    public var humidity: Int
    public var windSpeed: Double
    public var windDeg: Int
    public var windGust: Double
    public var pressure: Int
    public var clouds: Int
    public var visibility: Double
    public var uvi: Double
    public var weatherCode: Int
    public var isDay: Bool
    /// "yyyy-MM-ddTHH:mm" local time.
    public var dt: String
    public var provider: WeatherSource
}

public struct HourlyForecast: Codable, Hashable, Sendable, Identifiable {
    public var id: String { dt }
    public var dt: String
    public var temp: Double
    public var humidity: Int
    public var windSpeed: Double
    public var windDeg: Int
    /// 0…1
    public var pop: Double
    public var weatherCode: Int
    public var isDay: Bool

    /// "HH:mm" for the hourly strip.
    public var timeLabel: String { String(dt.dropFirst(11).prefix(5)) }
}

public struct DailyForecast: Codable, Hashable, Sendable, Identifiable {
    public var id: String { dt }
    /// "yyyy-MM-dd"
    public var dt: String
    public var sunrise: String
    public var sunset: String
    public var tempMax: Double
    public var tempMin: Double
    public var pop: Double
    public var uvi: Double
    public var windSpeed: Double
    public var weatherCode: Int
}

public struct StationBlock: Codable, Hashable, Sendable {
    public var healthy: Bool
    public var reason: String?
    public var updatedAt: String?
    public var rows: Int
    public var latest: StationSample?
    public var today: [StationSample]
    public var units: [String: String]
}

public struct StationSample: Codable, Hashable, Sendable, Identifiable {
    public var id: String { time }
    /// "HH:MM" local
    public var time: String
    public var windSpeed: Double
    public var windDeg: Int
    public var temp: Double
    public var humidity: Double
    public var precipitation: Double
    public var pressure: Double
    public var radiation: Double
}

// MARK: - Grade discovery (shared by the schedule list and the PDF viewer)

/// Grade discovery from a schedule link title, so a new Jahrgang (J13, a split
/// "J11" / "J12" upload, …) needs no app update.
public enum ScheduleGrades {
    /// Grades named in a schedule link title; ranges ("5-10", "11-12") are expanded,
    /// "J11", "J11/12", "J 13" are read as Jahrgang numbers.
    public static func fromTitle(_ title: String) -> [Int] {
        // only the part after the last " - " names the grades ("Stundenpläne - 2026/2027 - 1.HJ - J11")
        let tail = title.components(separatedBy: " - ").last ?? title
        var grades = Set<Int>()
        for m in tail.matches(of: #/(\d{1,2})\s*-\s*(\d{1,2})/#) {
            if let a = Int(m.1), let b = Int(m.2), a <= b, b - a < 20 { grades.formUnion(a...b) }
        }
        for m in tail.matches(of: #/[Jj]\s*(\d{1,2})(?:\s*/\s*(\d{1,2}))?/#) {
            if let a = Int(m.1) { grades.insert(a) }
            if let second = m.2, let b = Int(second) { grades.insert(b) }
        }
        return grades.sorted()
    }

    /// "10b" → 10, "j11" → 11, "J13" → 13; nil for anything else.
    public static func gradeOf(_ cls: String) -> Int? {
        let lower = cls.lowercased()
        if let m = lower.wholeMatch(of: #/j(\d{1,2})/#) { return Int(m.1) }
        if let m = lower.wholeMatch(of: #/(\d{1,2})[a-e]/#) { return Int(m.1) }
        return nil
    }

    /// Is `cls` a class or Jahrgang token the app accepts ("5a"…"10e", "j11", "j13", …)?
    public static func isClassToken(_ cls: String) -> Bool { gradeOf(cls) != nil }
}
