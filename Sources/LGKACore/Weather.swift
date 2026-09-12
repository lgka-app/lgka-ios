import Foundation

/// Open-Meteo response mapper — Swift port of WeatherService.fetchAll's
/// parsing (weather_service.dart), verified against the weather goldens.
///
/// Decoding is `Codable`-based and throws `LGKAError` on a malformed payload;
/// nothing in here can trap on server data.
///
/// `referenceNow` is the recorded hourly-window start from the golden params;
/// the window is [referenceNow, referenceNow + 24h).
public enum WeatherParser {
    // MARK: Wire format

    struct Response: Decodable {
        let current: Current
        let hourly: Hourly
        let daily: Daily
    }

    struct Current: Decodable {
        let time: String
        let temperature_2m: Double?
        let relative_humidity_2m: Double?
        let apparent_temperature: Double?
        let weather_code: Double?
        let wind_speed_10m: Double?
        let wind_direction_10m: Double?
        let wind_gusts_10m: Double?
        let pressure_msl: Double?
        let cloud_cover: Double?
        let visibility: Double?
        let uv_index: Double?
        let is_day: Double?
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double?]
        let relative_humidity_2m: [Double?]
        let weather_code: [Double?]
        let precipitation_probability: [Double?]
        let wind_speed_10m: [Double?]
        let wind_direction_10m: [Double?]
        let is_day: [Double?]
    }

    struct Daily: Decodable {
        let time: [String]
        let weather_code: [Double?]
        let temperature_2m_max: [Double?]
        let temperature_2m_min: [Double?]
        let precipitation_probability_max: [Double?]
        let uv_index_max: [Double?]
        let wind_speed_10m_max: [Double?]
        let sunrise: [String]
        let sunset: [String]
    }

    // MARK: Helpers

    /// Dart DateTime.toIso8601String() for a naive local time.
    private static func iso(_ s: String) -> String {
        // input "yyyy-MM-ddTHH:mm" (Open-Meteo) -> "yyyy-MM-ddTHH:mm:00.000"
        var t = s
        if t.count == 10 { t += "T00:00" } // daily dates
        return t.count == 16 ? "\(t):00.000" : t
    }

    /// Minutes since 1970-01-01T00:00 for a naive "yyyy-MM-ddTHH:mm" string,
    /// computed arithmetically (no calendar, no time zone): the window spans
    /// 24h of Berlin wall-clock time exactly like the Dart reference.
    static func minuteKey(_ s: String) throws -> Int {
        let p = Array(s.utf8.prefix(16))
        guard p.count == 16,
              let y = Int(String(decoding: p[0..<4], as: UTF8.self)),
              let mo = Int(String(decoding: p[5..<7], as: UTF8.self)),
              let d = Int(String(decoding: p[8..<10], as: UTF8.self)),
              let h = Int(String(decoding: p[11..<13], as: UTF8.self)),
              let mi = Int(String(decoding: p[14..<16], as: UTF8.self)),
              (1...12).contains(mo), (1...31).contains(d), (0...23).contains(h),
              (0...59).contains(mi)
        else { throw LGKAError.invalidJSON("bad timestamp \(s)") }
        return daysFromCivil(y, mo, d) * 1440 + h * 60 + mi
    }

    /// Howard Hinnant's days-from-civil (proleptic Gregorian).
    private static func daysFromCivil(_ y: Int, _ m: Int, _ d: Int) -> Int {
        let y = m <= 2 ? y - 1 : y
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    private static func req(_ v: Double?, _ name: String) throws -> Double {
        guard let v else { throw LGKAError.missingField(name) }
        return v
    }

    private static func at(_ a: [Double?], _ i: Int) -> Double {
        // Arrays can be shorter than `time` or hold nulls at the horizon;
        // the Dart reference would fail the whole fetch — we degrade to 0.
        i < a.count ? (a[i] ?? 0) : 0
    }

    private static func at(_ a: [String], _ i: Int) -> String {
        i < a.count ? a[i] : ""
    }

    // MARK: Parse

    public static func parse(_ jsonText: String, referenceNow: String) throws -> [String: Any] {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: Data(jsonText.utf8))
        } catch {
            throw LGKAError.invalidJSON(String(describing: error))
        }

        let c = response.current
        let current: [String: Any] = [
            "temp": try req(c.temperature_2m, "current.temperature_2m"),
            "feelsLike": try req(c.apparent_temperature, "current.apparent_temperature"),
            "humidity": Int(try req(c.relative_humidity_2m, "current.relative_humidity_2m")),
            "windSpeed": try req(c.wind_speed_10m, "current.wind_speed_10m"),
            "windDeg": Int(try req(c.wind_direction_10m, "current.wind_direction_10m")),
            "windGust": c.wind_gusts_10m ?? 0,
            "pressure": Int((try req(c.pressure_msl, "current.pressure_msl")).rounded()),
            "clouds": Int(c.cloud_cover ?? 0),
            "visibility": c.visibility ?? 0,
            "uvi": c.uv_index ?? 0,
            "weatherCode": Int(try req(c.weather_code, "current.weather_code")),
            "isDay": Int(c.is_day ?? 1) == 1,
            "dt": iso(c.time),
        ]

        let h = response.hourly
        let winStart = try minuteKey(referenceNow)
        let winEnd = winStart + 24 * 60
        var hourly: [[String: Any]] = []
        for (i, time) in h.time.enumerated() {
            let key = try minuteKey(time)
            guard key >= winStart, key < winEnd else { continue }
            hourly.append([
                "dt": iso(time),
                "temp": at(h.temperature_2m, i),
                "humidity": Int(at(h.relative_humidity_2m, i)),
                "windSpeed": at(h.wind_speed_10m, i),
                "windDeg": Int(at(h.wind_direction_10m, i)),
                "pop": at(h.precipitation_probability, i) / 100.0,
                "weatherCode": Int(at(h.weather_code, i)),
                "isDay": Int(at(h.is_day, i)) == 1,
            ])
        }

        let d = response.daily
        var daily: [[String: Any]] = []
        for (i, time) in d.time.enumerated() {
            daily.append([
                "dt": iso(time),
                "sunrise": iso(at(d.sunrise, i)),
                "sunset": iso(at(d.sunset, i)),
                "tempMax": at(d.temperature_2m_max, i),
                "tempMin": at(d.temperature_2m_min, i),
                "pop": at(d.precipitation_probability_max, i) / 100.0,
                "uvi": at(d.uv_index_max, i),
                "windSpeed": at(d.wind_speed_10m_max, i),
                "weatherCode": Int(at(d.weather_code, i)),
            ])
        }

        return ["current": current, "hourly": hourly, "daily": daily]
    }
}
