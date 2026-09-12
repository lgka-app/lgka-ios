import Foundation

/// The app's hourly window: [start of the reference hour, +24h) over Berlin
/// wall-clock strings ("yyyy-MM-ddTHH:mm"), computed arithmetically so no
/// calendar or time zone is involved (parity with the Flutter app).
public enum WeatherWindow {
    public static func window(_ hourly: [HourlyForecast], from localNow: String, hours: Int = 24) -> [HourlyForecast] {
        guard let start = minuteKey(String(localNow.prefix(13)) + ":00") else { return [] }
        let end = start + hours * 60
        return hourly.filter { h in
            guard let key = minuteKey(h.dt) else { return false }
            return key >= start && key < end
        }
    }

    /// Minutes since 1970-01-01T00:00 for a naive "yyyy-MM-ddTHH:mm" string.
    public static func minuteKey(_ s: String) -> Int? {
        let p = Array(s.utf8.prefix(16))
        guard p.count == 16,
              let y = Int(String(decoding: p[0..<4], as: UTF8.self)),
              let mo = Int(String(decoding: p[5..<7], as: UTF8.self)),
              let d = Int(String(decoding: p[8..<10], as: UTF8.self)),
              let h = Int(String(decoding: p[11..<13], as: UTF8.self)),
              let mi = Int(String(decoding: p[14..<16], as: UTF8.self)),
              (1...12).contains(mo), (1...31).contains(d), (0...23).contains(h), (0...59).contains(mi)
        else { return nil }
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

    /// "yyyy-MM-ddTHH:mm" for `date` in `timeZone` (Europe/Berlin by default — the API's clock).
    public static func localNow(_ date: Date = Date(), timeZone: TimeZone = TimeZone(identifier: "Europe/Berlin") ?? .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "%04d-%02d-%02dT%02d:%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }
}
