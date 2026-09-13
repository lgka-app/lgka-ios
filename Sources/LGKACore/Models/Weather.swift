import Foundation

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
