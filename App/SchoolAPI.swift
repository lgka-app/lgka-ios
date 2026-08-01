import Foundation
import LGKACore

/// UI-facing data access: networking + typed wrappers around the verified
/// LGKACore parsers. All parsing lives in the core — this file only fetches
/// and re-shapes dictionaries into models the views can render.
enum SchoolAPI {
    static let base = "https://lessing-gymnasium-karlsruhe.de"
    private static let auth =
        "Basic " + Data("vertretungsplan:ephraim".utf8).base64EncodedString()

    static func get(_ url: String, authenticated: Bool = true) async throws -> Data {
        var request = URLRequest(url: URL(string: url)!, timeoutInterval: 15)
        if authenticated { request.setValue(auth, forHTTPHeaderField: "Authorization") }
        request.setValue("LGKA+/3.0.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    // ── Substitution ────────────────────────────────────────────────────────

    struct SubPlan {
        struct Entry: Identifiable {
            let id = UUID()
            let type: String?, period: String?, classes: [String]
            let substitute: String?, subject: String?, room: String?
            let originalSubject: String?, originalTeacher: String?, originalRoom: String?
            let note: String?
        }
        let weekday: String?, planDate: String?, generatedAt: String?
        let isEmpty: Bool
        let announcements: [String], absentTeachers: [String], absentClasses: [String]
        let entries: [Entry]

        init(dict: [String: Any]) {
            func s(_ k: String) -> String? { dict[k] as? String }
            weekday = s("weekday"); planDate = s("planDate"); generatedAt = s("generatedAt")
            isEmpty = dict["isEmpty"] as? Bool ?? false
            announcements = dict["announcements"] as? [String] ?? []
            absentTeachers = dict["absentTeachers"] as? [String] ?? []
            absentClasses = dict["absentClasses"] as? [String] ?? []
            entries = (dict["entries"] as? [[String: Any]] ?? []).map { e in
                func es(_ k: String) -> String? { e[k] as? String }
                return Entry(
                    type: es("type"), period: es("period"),
                    classes: e["classes"] as? [String] ?? [],
                    substitute: es("substitute"), subject: es("subject"), room: es("room"),
                    originalSubject: es("originalSubject"),
                    originalTeacher: es("originalTeacher"),
                    originalRoom: es("originalRoom"), note: es("note"))
            }
        }
    }

    static func substitutionPlan(today: Bool) async throws -> SubPlan {
        let name = today ? "heute" : "morgen"
        let data = try await get("\(base)/stundenplan/schueler/v_schueler_\(name).pdf")
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("sub_\(name).pdf")
        try data.write(to: tmp)
        guard let lines = extractLines(from: tmp) else {
            throw URLError(.cannotParseResponse)
        }
        return SubPlan(dict: Extractor.extract(lines: lines))
    }

    // ── Schedule ────────────────────────────────────────────────────────────

    struct Schedule: Identifiable {
        var id: String { fullUrl }
        let title: String, halbjahr: String, gradeLevel: String, fullUrl: String
    }

    static func schedules() async throws -> [Schedule] {
        let data = try await get("\(base)/cm3/index.php/unterricht/stundenplan")
        let html = String(decoding: data, as: UTF8.self)
        return try ScheduleHtmlParser.parse(html).map {
            Schedule(title: $0["title"] as? String ?? "",
                     halbjahr: $0["halbjahr"] as? String ?? "",
                     gradeLevel: $0["gradeLevel"] as? String ?? "",
                     fullUrl: $0["fullUrl"] as? String ?? "")
        }
    }

    /// Downloads a schedule PDF, returns the local file URL + class index.
    static func schedulePdf(_ schedule: Schedule) async throws -> (URL, [String: Int]) {
        let data = try await get(schedule.fullUrl)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("schedule_\(abs(schedule.fullUrl.hashValue)).pdf")
        try data.write(to: tmp)
        if schedule.gradeLevel == "J11/J12" {
            return (tmp, ["j11": 2, "j12": 3]) // app-constant, never parsed
        }
        return (tmp, buildClassIndex(url: tmp) ?? [:])
    }

    // ── News ────────────────────────────────────────────────────────────────

    static func newsList() async throws -> [NewsParser.Metadata] {
        let data = try await get("\(base)/cm3/index.php/neues", authenticated: false)
        return try NewsParser.parseListPage(String(decoding: data, as: UTF8.self))
    }

    static func article(url: String) async throws -> NewsParser.Article {
        let data = try await get(url, authenticated: false)
        return try NewsParser.parseArticle(String(decoding: data, as: UTF8.self))
    }

    // ── Events ──────────────────────────────────────────────────────────────

    struct Event: Identifiable {
        let id = UUID()
        let date: String // yyyy-MM-dd
        let time: String?, title: String
    }

    static func events() async throws -> [Event] {
        let cal = Calendar.current
        let today = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd"
        var htmls: [String] = []
        for week in 0..<3 {
            let target = cal.date(byAdding: .day, value: week * 7, to: today)!
            let url = "\(base)/cm3/index.php/termine/week.listevents/\(df.string(from: target))/-?catids="
            let data = try await get(url, authenticated: false)
            htmls.append(String(decoding: data, as: UTF8.self))
        }
        df.dateFormat = "yyyy-MM-dd"
        let todayStr = df.string(from: today)
        return EventsParser.aggregate(weekHtmls: htmls, today: todayStr).map {
            Event(date: String(($0["date"] as? String ?? "").prefix(10)),
                  time: $0["time"] as? String,
                  title: $0["title"] as? String ?? "")
        }
    }

    // ── Weather ─────────────────────────────────────────────────────────────

    struct WeatherData {
        struct Hour: Identifiable {
            let id = UUID()
            let time: String, temp: Double, pop: Double, code: Int, isDay: Bool
        }
        struct Day: Identifiable {
            let id = UUID()
            let date: String, tempMax: Double, tempMin: Double, pop: Double, code: Int
        }
        let temp: Double, feelsLike: Double, humidity: Int, windSpeed: Double
        let pressure: Int, uvi: Double, code: Int, isDay: Bool
        let hourly: [Hour], daily: [Day]
    }

    static func weather() async throws -> WeatherData {
        let url = "https://api.open-meteo.com/v1/forecast?latitude=49.00775&longitude=8.375&elevation=122"
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl,cloud_cover,visibility,uv_index,is_day"
            + "&hourly=temperature_2m,relative_humidity_2m,weather_code,precipitation_probability,wind_speed_10m,wind_direction_10m,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max,wind_speed_10m_max,sunrise,sunset"
            + "&timezone=Europe%2FBerlin&forecast_days=3"
        let data = try await get(url, authenticated: false)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:00"
        let refNow = df.string(from: Date())
        let parsed = try WeatherParser.parse(
            String(decoding: data, as: UTF8.self), referenceNow: refNow)

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
        case 61, 80: return "cloud.rain.fill"
        case 63, 81: return "cloud.rain.fill"
        case 65, 82: return "cloud.heavyrain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func description(_ code: Int) -> String {
        switch code {
        case 0: return "Klarer Himmel"
        case 1: return "Überwiegend klar"
        case 2: return "Teilweise bewölkt"
        case 3: return "Bedeckt"
        case 45: return "Nebel"
        case 48: return "Gefrierender Nebel"
        case 51: return "Leichter Nieselregen"
        case 53: return "Mäßiger Nieselregen"
        case 55: return "Dichter Nieselregen"
        case 56, 57: return "Gefrierender Nieselregen"
        case 61: return "Leichter Regen"
        case 63: return "Mäßiger Regen"
        case 65: return "Starker Regen"
        case 66, 67: return "Gefrierender Regen"
        case 71: return "Leichter Schneefall"
        case 73: return "Mäßiger Schneefall"
        case 75: return "Starker Schneefall"
        case 77: return "Schneekörner"
        case 80: return "Leichte Regenschauer"
        case 81: return "Mäßige Regenschauer"
        case 82: return "Starke Regenschauer"
        case 85, 86: return "Schneeschauer"
        case 95: return "Gewitter"
        case 96, 99: return "Gewitter mit Hagel"
        default: return "Unbekannt"
        }
    }
}

/// "yyyy-MM-dd" -> "Mo., 14.09." style German label.
func germanDayLabel(_ iso: String) -> String {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    guard let date = df.date(from: iso) else { return iso }
    let out = DateFormatter()
    out.locale = Locale(identifier: "de_DE")
    out.dateFormat = "EE, d. MMMM"
    return out.string(from: date)
}
