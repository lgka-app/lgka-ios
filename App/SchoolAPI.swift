import Foundation
import os
import LGKACore

enum SchoolAPIError: Error, Sendable {
    case notAuthenticated
    case badStatus(Int)
    case invalidURL(String)
}

/// UI-facing data access: networking + typed wrappers around the verified
/// LGKACore parsers. All parsing lives in the core — this file only fetches
/// and re-shapes parser output into models the views can render.
enum SchoolAPI {
    static let log = Logger(subsystem: "com.lgka", category: "api")
    static let base = "https://lessing-gymnasium-karlsruhe.de"
    static let host = "lessing-gymnasium-karlsruhe.de"
    /// Same User-Agent format the Flutter app sends (app_info.dart).
    static let userAgent = "LGKA-App-Luka-Loehr/" +
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0")

    static func isSchoolHost(_ host: String?) -> Bool {
        guard let host else { return false }
        return host == Self.host || host.hasSuffix("." + Self.host)
    }

    private static func request(_ url: String, authorization: String?) throws -> URLRequest {
        guard let target = URL(string: url) else { throw SchoolAPIError.invalidURL(url) }
        var request = URLRequest(url: target, timeoutInterval: 15)
        if let authorization, isSchoolHost(target.host) {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    static func fetch(_ url: String, authenticated: Bool = true) async throws -> Data {
        var authorization: String? = nil
        if authenticated {
            guard let creds = Credentials.load() else { throw SchoolAPIError.notAuthenticated }
            authorization = creds.authorizationHeader
        }
        let (data, response) = try await URLSession.shared.data(for: request(url, authorization: authorization))
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else {
            log.error("GET \(url, privacy: .public) -> \(http.statusCode)")
            throw SchoolAPIError.badStatus(http.statusCode)
        }
        return data
    }

    /// Login gate: the credentials are checked against the server (a HEAD
    /// on the substitution PDF), never against a string in the app.
    static func verify(_ pair: Credentials.Pair) async throws -> Bool {
        var req = try request("\(base)/stundenplan/schueler/v_schueler_heute.pdf",
                              authorization: pair.authorizationHeader)
        req.httpMethod = "HEAD"
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch http.statusCode {
        case 200: return true
        case 401, 403: return false
        default: throw SchoolAPIError.badStatus(http.statusCode)
        }
    }

    // ── Substitution ────────────────────────────────────────────────────────

    struct SubPlan: Sendable {
        struct Entry: Sendable, Identifiable {
            let id: Int
            let type: String?, period: String?, classes: [String]
            let substitute: String?, subject: String?, room: String?
            let originalSubject: String?, originalTeacher: String?, originalRoom: String?
            let note: String?
        }
        let weekday: String?, planDate: String?, generatedAt: String?
        let isEmpty: Bool
        let announcements: [String], absentTeachers: [String], absentClasses: [String]
        let entries: [Entry]
        var fileUrl: URL?

        /// Mirrors SubstitutionState.canDisplay.
        var canDisplay: Bool {
            !isEmpty && weekday != nil && weekday != "weekend"
                && planDate != nil && fileUrl != nil
        }

        init(dict: [String: Any]) {
            func s(_ k: String) -> String? { dict[k] as? String }
            weekday = s("weekday"); planDate = s("planDate"); generatedAt = s("generatedAt")
            isEmpty = dict["isEmpty"] as? Bool ?? false
            announcements = dict["announcements"] as? [String] ?? []
            absentTeachers = dict["absentTeachers"] as? [String] ?? []
            absentClasses = dict["absentClasses"] as? [String] ?? []
            entries = (dict["entries"] as? [[String: Any]] ?? []).enumerated().map { i, e in
                func es(_ k: String) -> String? { e[k] as? String }
                return Entry(
                    id: i, type: es("type"), period: es("period"),
                    classes: e["classes"] as? [String] ?? [],
                    substitute: es("substitute"), subject: es("subject"), room: es("room"),
                    originalSubject: es("originalSubject"),
                    originalTeacher: es("originalTeacher"),
                    originalRoom: es("originalRoom"), note: es("note"))
            }
        }
    }

    static func substitutionPlan(today: Bool, mode: FetchMode = .cacheFirst) async throws -> SubPlan {
        let name = today ? "heute" : "morgen"
        let url = "\(base)/stundenplan/schueler/v_schueler_\(name).pdf"
        let data = try await cachedGet(url, ttl: TTL.substitution, mode: mode)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("sub_\(name).pdf")
        try data.write(to: tmp, options: .atomic)
        do {
            var plan = SubPlan(dict: try Extractor.extract(lines: try extractLines(from: tmp)))
            plan.fileUrl = tmp
            return plan
        } catch {
            // A payload that cannot be parsed must not be served again from
            // the cache on the next cold start.
            Cache.remove(url)
            throw error
        }
    }

    // ── Schedule ────────────────────────────────────────────────────────────

    typealias Schedule = ScheduleHtmlParser.Schedule

    static func schedules(mode: FetchMode = .cacheFirst) async throws -> [Schedule] {
        let url = "\(base)/cm3/index.php/unterricht/stundenplan"
        let data = try await cachedGet(url, ttl: TTL.schedules, mode: mode)
        do {
            return try ScheduleHtmlParser.schedules(String(decoding: data, as: UTF8.self))
        } catch {
            Cache.remove(url)
            throw error
        }
    }

    /// Downloads a schedule PDF, returns the local file URL + class index.
    static func schedulePdf(_ schedule: Schedule, mode: FetchMode = .cacheFirst) async throws -> (URL, [String: Int]) {
        let data = try await cachedGet(schedule.fullUrl, ttl: TTL.schedules, mode: mode)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("schedule_\(Cache.key(schedule.fullUrl)).pdf")
        try data.write(to: tmp, options: .atomic)
        // classes 5a…10e from the page texts, Jahrgänge from the "J11"/"J12"/… page headers
        var index = try buildClassIndex(url: tmp)
        index.merge(try buildJahrgangIndex(url: tmp)) { first, _ in first }
        // a single-Jahrgang PDF whose page carries no header still maps to its first page
        let grades = schedule.grades
        if grades.count == 1, let g = grades.first, g >= 11, index["j\(g)"] == nil { index["j\(g)"] = 2 }
        return (tmp, index)
    }

    // ── News ────────────────────────────────────────────────────────────────

    static func newsList(mode: FetchMode = .cacheFirst) async throws -> [NewsParser.Metadata] {
        let data = try await cachedGet("\(base)/cm3/index.php/neues",
                                       authenticated: false, ttl: TTL.news, mode: mode)
        return try NewsParser.parseListPage(String(decoding: data, as: UTF8.self))
    }

    static func article(url: String, mode: FetchMode = .cacheFirst) async throws -> NewsParser.Article {
        let data = try await cachedGet(url, authenticated: false, ttl: TTL.news, mode: mode)
        return try NewsParser.parseArticle(String(decoding: data, as: UTF8.self))
    }

    // ── Events ──────────────────────────────────────────────────────────────

    struct Event: Sendable, Identifiable, Hashable {
        var id: String { "\(date)|\(title)" }
        let date: String // yyyy-MM-dd
        let time: String?, title: String
    }

    static func events(mode: FetchMode = .cacheFirst) async throws -> [Event] {
        let cal = Calendar.current
        let today = Date()
        var htmls: [String] = []
        for week in 0..<3 {
            guard let target = cal.date(byAdding: .day, value: week * 7, to: today) else { continue }
            let c = cal.dateComponents([.year, .month, .day], from: target)
            let path = String(format: "%04d/%02d/%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
            let url = "\(base)/cm3/index.php/termine/week.listevents/\(path)/-?catids="
            let data = try await cachedGet(url, authenticated: false, ttl: TTL.events, mode: mode)
            htmls.append(String(decoding: data, as: UTF8.self))
        }
        let todayStr = LocalDate.isoString(today)
        return EventsParser.upcoming(weekHtmls: htmls, today: todayStr).map {
            Event(date: $0.date, time: $0.time, title: $0.title)
        }
    }

    // ── Weather ─────────────────────────────────────────────────────────────

    struct WeatherData: Sendable {
        struct Hour: Sendable, Identifiable {
            var id: String { time }
            let time: String, temp: Double, pop: Double, code: Int, isDay: Bool
        }
        struct Day: Sendable, Identifiable {
            var id: String { date }
            let date: String, tempMax: Double, tempMin: Double, pop: Double, code: Int
        }
        let temp: Double, feelsLike: Double, humidity: Int, windSpeed: Double
        let pressure: Int, uvi: Double, code: Int, isDay: Bool
        let hourly: [Hour], daily: [Day]
    }

    static let weatherURL = "https://api.open-meteo.com/v1/forecast?latitude=49.00775&longitude=8.375&elevation=122"
        + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl,cloud_cover,visibility,uv_index,is_day"
        + "&hourly=temperature_2m,relative_humidity_2m,weather_code,precipitation_probability,wind_speed_10m,wind_direction_10m,is_day"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max,wind_speed_10m_max,sunrise,sunset"
        + "&timezone=Europe%2FBerlin&forecast_days=3"

    static func weather(mode: FetchMode = .cacheFirst) async throws -> WeatherData {
        let data = try await cachedGet(weatherURL, authenticated: false,
                                       ttl: TTL.weather, mode: mode)
        let refNow = LocalDate.hourString(Date())
        let parsed: [String: Any]
        do {
            parsed = try WeatherParser.parse(String(decoding: data, as: UTF8.self), referenceNow: refNow)
        } catch {
            Cache.remove(weatherURL)
            throw error
        }

        let c = parsed["current"] as? [String: Any] ?? [:]
        func d(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }
        func i(_ v: Any?) -> Int { (v as? NSNumber)?.intValue ?? 0 }
        let hourly = (parsed["hourly"] as? [[String: Any]] ?? []).map { h in
            WeatherData.Hour(
                time: String((h["dt"] as? String ?? "").dropFirst(11).prefix(5)),
                temp: d(h["temp"]), pop: d(h["pop"]),
                code: i(h["weatherCode"]), isDay: h["isDay"] as? Bool ?? true)
        }
        let daily = (parsed["daily"] as? [[String: Any]] ?? []).map { day in
            WeatherData.Day(
                date: String((day["dt"] as? String ?? "").prefix(10)),
                tempMax: d(day["tempMax"]), tempMin: d(day["tempMin"]),
                pop: d(day["pop"]), code: i(day["weatherCode"]))
        }
        return WeatherData(
            temp: d(c["temp"]), feelsLike: d(c["feelsLike"]), humidity: i(c["humidity"]),
            windSpeed: d(c["windSpeed"]), pressure: i(c["pressure"]), uvi: d(c["uvi"]),
            code: i(c["weatherCode"]), isDay: c["isDay"] as? Bool ?? true,
            hourly: hourly, daily: daily)
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

    static func isoString(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "yyyy-MM-ddTHH:00" (Open-Meteo hourly window start).
    static func hourString(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour], from: date)
        return isoString(date) + String(format: "T%02d:00", c.hour ?? 0)
    }

    static func isToday(_ iso: String) -> Bool {
        guard let date = parse(iso) else { return false }
        return calendar.isDateInToday(date)
    }
}
