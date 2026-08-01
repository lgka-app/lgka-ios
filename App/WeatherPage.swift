import SwiftUI

/// Full weather page — mirrors weather_page.dart.
struct WeatherPageScreen: View {
    @ObservedObject var model: HomeModel
    @Environment(\.appAccent) private var accent

    var body: some View {
        Group {
            if let w = model.weather {
                content(w)
            } else if model.weatherError {
                VStack(spacing: 8) {
                    Image(systemName: "cloud.slash")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text(L.s("weatherDataNotAvailable")).font(.body.weight(.semibold))
                    Text(L.s("checkInternetConnection"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
            }
        }
        .themeBg()
        .navigationTitle(L.s("weatherPageTitle"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ w: SchoolAPI.WeatherData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroCard(w)
                statsRow(w).padding(.top, 16)
                if !w.hourly.isEmpty {
                    caps(L.s("hourlyForecastLabel")).padding(.top, 28)
                    hourlyScroll(w).padding(.top, 12)
                }
                if !w.daily.isEmpty {
                    caps(L.s("threeDayForecastLabel")).padding(.top, 28)
                    dailyList(w).padding(.top, 12)
                }
                attribution.padding(.top, 32)
                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private func caps(_ s: String) -> some View {
        Text(s).font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .kerning(0.6)
    }

    private func heroCard(_ w: SchoolAPI.WeatherData) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: Wmo.symbol(w.code, isDay: w.isDay))
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                Text("\(Int(w.temp.rounded()))°")
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(.white)
            }
            Text(L.wmo(w.code))
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.95))
            Text(feelsLine(w))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .shadow(color: .black.opacity(0.38), radius: 8)
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .background(WeatherScene.gradient(w.code, isDay: w.isDay))
        .overlay(LinearGradient(colors: [.clear, .black.opacity(0.16)],
                                startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func feelsLine(_ w: SchoolAPI.WeatherData) -> String {
        let feels = Int(w.feelsLike.rounded())
        if let today = w.daily.first {
            let hi = Int(today.tempMax.rounded()), lo = Int(today.tempMin.rounded())
            return L.isGerman
                ? "Gefühlt \(feels)°  ·  \(lo)° – \(hi)°"
                : "Feels like \(feels)°  ·  \(lo)° – \(hi)°"
        }
        return L.isGerman ? "Gefühlt \(feels)°" : "Feels like \(feels)°"
    }

    private func statsRow(_ w: SchoolAPI.WeatherData) -> some View {
        HStack(spacing: 10) {
            statChip("drop", "\(w.humidity)%", L.s("weatherHumidityShort"))
            statChip("wind", "\(Int(w.windSpeed.rounded())) km/h", L.s("weatherWindShort"))
            statChip("gauge.with.needle", "\(w.pressure)", "hPa")
            statChip("sun.max", String(format: "%.1f", w.uvi), uviLabel(w.uvi))
        }
    }

    private func statChip(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.footnote).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold)).lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .surfaceCard(radius: 14)
    }

    private func uviLabel(_ uvi: Double) -> String {
        if uvi < 3 { return L.s("uviLow") }
        if uvi < 6 { return L.s("uviMedium") }
        if uvi < 8 { return L.s("uviHigh") }
        if uvi < 11 { return L.s("uviVeryHigh") }
        return L.s("uviExtreme")
    }

    private func hourlyScroll(_ w: SchoolAPI.WeatherData) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(w.hourly) { h in
                    VStack(spacing: 6) {
                        Text(h.time).font(.caption2).foregroundStyle(.secondary)
                        Image(systemName: Wmo.symbol(h.code, isDay: h.isDay))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("\(Int(h.temp.rounded()))°")
                            .font(.subheadline.weight(.semibold))
                        if h.pop >= 0.1 {
                            Text("\(Int(h.pop * 100))%")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(accent)
                        } else {
                            Spacer().frame(height: 13)
                        }
                    }
                    .frame(width: 64)
                    .padding(.vertical, 10)
                    .surfaceCard(radius: 14)
                }
            }
        }
    }

    private func dailyList(_ w: SchoolAPI.WeatherData) -> some View {
        let weekMin = w.daily.map(\.tempMin).min() ?? 0
        let weekMax = w.daily.map(\.tempMax).max() ?? 1
        let span = max(weekMax - weekMin, 1)

        return VStack(spacing: 0) {
            ForEach(Array(w.daily.enumerated()), id: \.element.id) { i, d in
                HStack(spacing: 8) {
                    Text(dayLabel(d.date))
                        .font(.subheadline.weight(isToday(d.date) ? .bold : .medium))
                        .foregroundStyle(isToday(d.date) ? accent : .primary)
                        .frame(width: 48, alignment: .leading)
                    Image(systemName: Wmo.symbol(d.code, isDay: true))
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(width: 30)
                    Text(d.pop >= 0.1 ? "\(Int(d.pop * 100))%" : "")
                        .font(.caption2.weight(.medium)).foregroundStyle(accent)
                        .frame(width: 36)
                    Text("\(Int(d.tempMin.rounded()))°")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                    GeometryReader { geo in
                        let start = (d.tempMin - weekMin) / span
                        let end = (d.tempMax - weekMin) / span
                        ZStack(alignment: .leading) {
                            Capsule().fill(.secondary.opacity(0.12)).frame(height: 4)
                            Capsule()
                                .fill(LinearGradient(colors: [accent.opacity(0.6), accent],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(4, geo.size.width * (end - start)), height: 4)
                                .offset(x: geo.size.width * start)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    Text("\(Int(d.tempMax.rounded()))°")
                        .font(.caption.weight(.semibold))
                        .frame(width: 30, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                if i < w.daily.count - 1 { Divider().padding(.leading, 16) }
            }
        }
        .surfaceCard()
    }

    private func isToday(_ iso: String) -> Bool {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return iso == df.string(from: Date())
    }

    private func dayLabel(_ iso: String) -> String {
        if isToday(iso) { return L.s("today") }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.locale = Locale(identifier: L.isGerman ? "de_DE" : "en_US")
        out.dateFormat = "EEE"
        return out.string(from: date)
    }

    private var attribution: some View {
        HStack {
            Spacer()
            Link(L.s("weatherAttribution"),
                 destination: URL(string: "https://open-meteo.com/")!)
                .font(.caption)
                .foregroundStyle(accent.opacity(0.6))
            Spacer()
        }
    }
}
