import SwiftUI
import LGKACore

extension WeatherPageScreen {
    // ── Cards ───────────────────────────────────────────────────────────────

    private func cardHeader(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(label)
            Spacer()
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white.opacity(0.75))
        .accessibilityAddTraits(.isHeader)
    }

    private func cardBackground() -> some ShapeStyle {
        // Reduce Transparency: fall back to a solid dark surface.
        reduceTransparency
            ? AnyShapeStyle(Color.black.opacity(0.7))
            : AnyShapeStyle(.thinMaterial)
    }

    func hourlyCard(_ hours: [HourlyForecast]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("clock", L.s("hourlyForecastLabel"))
            Divider().overlay(.white.opacity(0.2))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(hours) { h in
                        VStack(spacing: 8) {
                            Text(h.timeLabel)
                                .font(.footnote.weight(.semibold))
                            Image(systemName: Wmo.symbol(h.weatherCode, isDay: h.isDay))
                                .symbolRenderingMode(.multicolor)
                                .font(.title3)
                                .frame(height: 24)
                            if h.pop >= 0.1 {
                                Text("\(Int(h.pop * 100))%")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.cyan)
                            }
                            Text("\(Int(h.temp.rounded()))°")
                                .font(.callout.weight(.semibold))
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(L.f("a11y.hour", h.timeLabel, Int(h.temp.rounded()), Wmo.description(h.weatherCode)))
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(cardBackground(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    func dailyCard(_ w: WeatherData) -> some View {
        let weekMin = w.daily.map(\.tempMin).min() ?? 0
        let weekMax = w.daily.map(\.tempMax).max() ?? 1
        let span = max(weekMax - weekMin, 1)

        return VStack(alignment: .leading, spacing: 4) {
            cardHeader("calendar", L.s("threeDayForecastLabel"))
            ForEach(w.daily) { d in
                Divider().overlay(.white.opacity(0.2))
                HStack(spacing: 10) {
                    Text(dayLabel(d.dt))
                        .font(.callout.weight(.medium))
                        .frame(width: 52, alignment: .leading)
                    Image(systemName: Wmo.symbol(d.weatherCode, isDay: true))
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 28)
                    Text(d.pop >= 0.1 ? "\(Int(d.pop * 100))%" : "")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 36, alignment: .leading)
                    Text("\(Int(d.tempMin.rounded()))°")
                        .font(.callout)
                        .opacity(0.7)
                    GeometryReader { geo in
                        let start = (d.tempMin - weekMin) / span
                        let end = (d.tempMax - weekMin) / span
                        ZStack(alignment: .leading) {
                            Capsule().fill(.black.opacity(0.25)).frame(height: 5)
                            Capsule()
                                .fill(LinearGradient(colors: [.cyan, .yellow],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(6, geo.size.width * (end - start)), height: 5)
                                .offset(x: geo.size.width * start)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(height: 30)
                    Text("\(Int(d.tempMax.rounded()))°")
                        .font(.callout.weight(.semibold))
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L.f("a11y.day", dayLabel(d.dt), Wmo.description(d.weatherCode),
                                        Int(d.tempMax.rounded()), Int(d.tempMin.rounded())))
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(cardBackground(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    func statsGrid(_ w: WeatherData) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
                  spacing: 14) {
            statTile("humidity", L.s("weatherHumidityShort"), "\(w.current.humidity) %")
            statTile("wind", L.s("weatherWindShort"), "\(Int(w.current.windSpeed.rounded())) km/h")
            statTile("gauge.with.needle", L.s("pressure"), "\(w.current.pressure) hPa")
            statTile("sun.max.fill", L.s("uvIndex"),
                     "\(String(format: "%.1f", w.current.uvi)) · \(uviLabel(w.current.uvi))")
        }
    }

    /// Source + attribution exactly as the API declares them: the school's
    /// rooftop station for current values when it is healthy, Open-Meteo otherwise.
    func attribution(_ w: WeatherData) -> some View {
        VStack(spacing: 6) {
            if w.source == .school {
                Label(L.s("weather.sourceSchool"), systemImage: "building.2")
                    .font(.caption.weight(.semibold))
            }
            ForEach(w.attribution, id: \.self) { line in
                if line.localizedCaseInsensitiveContains("open-meteo"), let url = URL(string: "https://open-meteo.com/") {
                    // attribution leaves the app: the user's own browser, like the Krankmeldung form
                    Button(line) {
                        Haptics.light()
                        Task { @MainActor in await UIApplication.shared.open(url) }
                    }
                    .buttonStyle(.plain)
                    .underline()
                } else {
                    Text(line)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.8))
        .multilineTextAlignment(.center)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func statTile(_ icon: String, _ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(label.uppercased())
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(14)
        .background(cardBackground(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    private func uviLabel(_ uvi: Double) -> String {
        if uvi < 3 { return L.s("uviLow") }
        if uvi < 6 { return L.s("uviMedium") }
        if uvi < 8 { return L.s("uviHigh") }
        if uvi < 11 { return L.s("uviVeryHigh") }
        return L.s("uviExtreme")
    }

    private func dayLabel(_ iso: String) -> String {
        if LocalDate.isToday(iso) { return L.s("today") }
        guard let date = LocalDate.parse(iso) else { return iso }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}
