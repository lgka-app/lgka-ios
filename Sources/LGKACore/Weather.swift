import Foundation

/// Open-Meteo response mapper — Swift port of WeatherService.fetchAll's
/// parsing (weather_service.dart), verified against the weather goldens.
///
/// referenceNow is the recorded hourly-window start from the golden params;
/// the window is [referenceNow, referenceNow + 24h).
public enum WeatherParser {
    /// Dart DateTime.toIso8601String() for a naive local time.
    private static func iso(_ s: String) -> String {
        // input "yyyy-MM-ddTHH:mm" (Open-Meteo) -> "yyyy-MM-ddTHH:mm:00.000"
        var t = s
        if t.count == 10 { t += "T00:00" } // daily dates
        return t.count == 16 ? "\(t):00.000" : t
    }

    /// Naive minutes-since-epoch-ish key for window comparison.
    private static func minuteKey(_ s: String) -> Int {
        // "yyyy-MM-ddTHH:mm..." -> comparable Int (naive; no DST concerns
        // because the window spans 24h of Berlin wall-clock time like Dart)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        let d = f.date(from: String(s.prefix(16)))!
        return Int(d.timeIntervalSince1970 / 60)
    }

    public static func parse(_ jsonText: String, referenceNow: String) throws -> [String: Any] {
        let root = try JSONSerialization.jsonObject(
            with: jsonText.data(using: .utf8)!) as! [String: Any]

        let c = root["current"] as! [String: Any]
        func num(_ v: Any?) -> Double { (v as! NSNumber).doubleValue }
        func int(_ v: Any?) -> Int { (v as! NSNumber).intValue }

        let current: [String: Any] = [
            "temp": num(c["temperature_2m"]),
            "feelsLike": num(c["apparent_temperature"]),
            "humidity": int(c["relative_humidity_2m"]),
            "windSpeed": num(c["wind_speed_10m"]),
            "windDeg": int(c["wind_direction_10m"]),
            "windGust": num(c["wind_gusts_10m"]),
            "pressure": Int(num(c["pressure_msl"]).rounded()),
            "clouds": int(c["cloud_cover"]),
            "visibility": num(c["visibility"]),
            "uvi": num(c["uv_index"]),
            "weatherCode": int(c["weather_code"]),
            "isDay": int(c["is_day"]) == 1,
            "dt": iso(c["time"] as! String),
        ]

        let h = root["hourly"] as! [String: Any]
        let hTimes = h["time"] as! [String]
        let winStart = minuteKey(referenceNow)
        let winEnd = winStart + 24 * 60
        var hourly: [[String: Any]] = []
        for i in 0..<hTimes.count {
            let key = minuteKey(hTimes[i])
            if key >= winStart && key < winEnd {
                hourly.append([
                    "dt": iso(hTimes[i]),
                    "temp": num((h["temperature_2m"] as! [Any])[i]),
                    "humidity": int((h["relative_humidity_2m"] as! [Any])[i]),
                    "windSpeed": num((h["wind_speed_10m"] as! [Any])[i]),
                    "windDeg": int((h["wind_direction_10m"] as! [Any])[i]),
                    "pop": num((h["precipitation_probability"] as! [Any])[i]) / 100.0,
                    "weatherCode": int((h["weather_code"] as! [Any])[i]),
                    "isDay": int((h["is_day"] as! [Any])[i]) == 1,
                ])
            }
        }

        let d = root["daily"] as! [String: Any]
        let dTimes = d["time"] as! [String]
        var daily: [[String: Any]] = []
        for i in 0..<dTimes.count {
            daily.append([
                "dt": iso(dTimes[i]),
                "sunrise": iso((d["sunrise"] as! [String])[i]),
                "sunset": iso((d["sunset"] as! [String])[i]),
                "tempMax": num((d["temperature_2m_max"] as! [Any])[i]),
                "tempMin": num((d["temperature_2m_min"] as! [Any])[i]),
                "pop": num((d["precipitation_probability_max"] as! [Any])[i]) / 100.0,
                "uvi": num((d["uv_index_max"] as! [Any])[i]),
                "windSpeed": num((d["wind_speed_10m_max"] as! [Any])[i]),
                "weatherCode": int((d["weather_code"] as! [Any])[i]),
            ])
        }

        return ["current": current, "hourly": hourly, "daily": daily]
    }
}
