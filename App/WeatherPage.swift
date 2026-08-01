import SwiftUI

/// Weather — Apple-Weather-style: full-bleed animated sky, big hero
/// typography, translucent material cards scrolling over the scene.
struct WeatherPageScreen: View {
    @ObservedObject var model: HomeModel
    @Environment(\.appAccent) private var accent

    var body: some View {
        ZStack {
            if let w = model.weather {
                SkyView(code: w.code, isDay: w.isDay)
                    .ignoresSafeArea()
                content(w)
            } else if model.weatherError {
                ContentUnavailableView {
                    Label(L.s("weatherDataNotAvailable"), systemImage: "cloud.slash")
                } description: {
                    Text(L.s("checkInternetConnection"))
                } actions: {
                    Button(L.s("tryAgain")) { Task { await model.loadWeather(mode: .refresh) } }
                        .buttonStyle(.bordered)
                }
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .refreshable { await model.loadWeather(mode: .refresh) }
    }

    private func content(_ w: SchoolAPI.WeatherData) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                hero(w)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                if !w.hourly.isEmpty { hourlyCard(w) }
                if !w.daily.isEmpty { dailyCard(w) }
                statsGrid(w)
                Link(L.s("weatherAttribution"),
                     destination: URL(string: "https://open-meteo.com/")!)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
        }
    }

    // ── Hero ────────────────────────────────────────────────────────────────

    private func hero(_ w: SchoolAPI.WeatherData) -> some View {
        VStack(spacing: 2) {
            Text("Karlsruhe")
                .font(.title2.weight(.medium))
            Text("\(Int(w.temp.rounded()))°")
                .font(.system(size: 96, weight: .thin))
                .padding(.leading, 24) // optically center over the degree sign
            Text(L.wmo(w.code))
                .font(.callout.weight(.medium))
                .opacity(0.9)
            if let today = w.daily.first {
                Text("H: \(Int(today.tempMax.rounded()))°  T: \(Int(today.tempMin.rounded()))°")
                    .font(.callout.weight(.medium))
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 8)
    }

    // ── Cards ───────────────────────────────────────────────────────────────

    private func cardHeader(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(label)
            Spacer()
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white.opacity(0.65))
    }

    private func hourlyCard(_ w: SchoolAPI.WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("clock", L.s("hourlyForecastLabel"))
            Divider().overlay(.white.opacity(0.2))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(w.hourly) { h in
                        VStack(spacing: 8) {
                            Text(h.time == w.hourly.first?.time ? L.s("today").prefix(5) + "" : h.time)
                                .font(.footnote.weight(.semibold))
                            Image(systemName: Wmo.symbol(h.code, isDay: h.isDay))
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
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
        .environment(\.colorScheme, .dark)
    }

    private func dailyCard(_ w: SchoolAPI.WeatherData) -> some View {
        let weekMin = w.daily.map(\.tempMin).min() ?? 0
        let weekMax = w.daily.map(\.tempMax).max() ?? 1
        let span = max(weekMax - weekMin, 1)

        return VStack(alignment: .leading, spacing: 4) {
            cardHeader("calendar", L.s("threeDayForecastLabel"))
            ForEach(Array(w.daily.enumerated()), id: \.element.id) { i, d in
                Divider().overlay(.white.opacity(0.2))
                HStack(spacing: 10) {
                    Text(dayLabel(d.date))
                        .font(.callout.weight(.medium))
                        .frame(width: 52, alignment: .leading)
                    Image(systemName: Wmo.symbol(d.code, isDay: true))
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
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
        .environment(\.colorScheme, .dark)
    }

    private func statsGrid(_ w: SchoolAPI.WeatherData) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
                  spacing: 14) {
            statTile("humidity", L.s("weatherHumidityShort"), "\(w.humidity) %")
            statTile("wind", L.s("weatherWindShort"), "\(Int(w.windSpeed.rounded())) km/h")
            statTile("gauge.with.needle", "hPa", "\(w.pressure)")
            statTile("sun.max.fill", "UV-Index",
                     "\(String(format: "%.1f", w.uvi)) · \(uviLabel(w.uvi))")
        }
    }

    private func statTile(_ icon: String, _ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(label.uppercased())
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
        .environment(\.colorScheme, .dark)
    }

    private func uviLabel(_ uvi: Double) -> String {
        if uvi < 3 { return L.s("uviLow") }
        if uvi < 6 { return L.s("uviMedium") }
        if uvi < 8 { return L.s("uviHigh") }
        if uvi < 11 { return L.s("uviVeryHigh") }
        return L.s("uviExtreme")
    }

    private func dayLabel(_ iso: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        if iso == df.string(from: Date()) { return L.s("today") }
        guard let date = df.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.locale = Locale(identifier: L.isGerman ? "de_DE" : "en_US")
        out.dateFormat = "EEE"
        return out.string(from: date)
    }
}

// ── Animated sky ────────────────────────────────────────────────────────────

/// Condition-aware animated sky: gradient + drifting cloud blobs, rain/snow
/// particles, night stars, sun glow — SwiftUI Canvas, no external assets.
struct SkyView: View {
    let code: Int
    let isDay: Bool

    private enum Precip { case none, rain, snow }
    private var precip: Precip {
        switch code {
        case 51...67, 80...82, 95, 96, 99: return .rain
        case 71...77, 85, 86: return .snow
        default: return .none
        }
    }
    private var cloudiness: Double {
        switch code {
        case 0, 1: return 0.15
        case 2: return 0.55
        case 45, 48: return 0.9
        default: return 0.85
        }
    }

    var body: some View {
        ZStack {
            WeatherScene.gradient(code, isDay: isDay)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    drawScene(ctx: &ctx, size: size, t: t)
                }
            }
        }
    }

    private func rand(_ i: Int, _ salt: Double) -> Double {
        // deterministic pseudo-random per particle index
        let v = sin(Double(i) * 127.1 + salt * 311.7) * 43758.5453
        return v - v.rounded(.down)
    }

    private func drawScene(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Sun glow / stars
        if isDay, cloudiness < 0.6 {
            let center = CGPoint(x: size.width * 0.78, y: size.height * 0.14)
            for (radius, alpha) in [(90.0, 0.35), (55.0, 0.5), (32.0, 0.95)] {
                let rect = CGRect(x: center.x - radius, y: center.y - radius,
                                  width: radius * 2, height: radius * 2)
                ctx.fill(Path(ellipseIn: rect),
                         with: .color(.yellow.opacity(alpha * (0.9 + 0.1 * sin(t)))))
            }
        } else if !isDay, cloudiness < 0.7 {
            for i in 0..<70 {
                let x = rand(i, 1) * size.width
                let y = rand(i, 2) * size.height * 0.55
                let twinkle = 0.4 + 0.6 * abs(sin(t * (0.5 + rand(i, 3)) + Double(i)))
                let s = 1.0 + rand(i, 4) * 1.6
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                         with: .color(.white.opacity(0.8 * twinkle)))
            }
        }

        // Drifting clouds (soft layered blobs)
        let cloudCount = Int(cloudiness * 10)
        for i in 0..<cloudCount {
            let speed = 12.0 + rand(i, 5) * 22.0
            let width = size.width * (0.35 + rand(i, 6) * 0.45)
            let x = (rand(i, 7) * (size.width + width) + t * speed)
                .truncatingRemainder(dividingBy: size.width + width) - width
            let y = size.height * (0.05 + rand(i, 8) * 0.38)
            let height = width * 0.32
            let alpha = (isDay ? 0.5 : 0.25) * (0.5 + rand(i, 9) * 0.5)
            var blob = ctx
            blob.addFilter(.blur(radius: 18))
            blob.fill(Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height)),
                      with: .color(.white.opacity(alpha)))
            blob.fill(Path(ellipseIn: CGRect(x: x + width * 0.2, y: y - height * 0.3,
                                             width: width * 0.6, height: height)),
                      with: .color(.white.opacity(alpha * 0.9)))
        }

        // Precipitation
        switch precip {
        case .rain:
            for i in 0..<90 {
                let speed = 550.0 + rand(i, 10) * 250.0
                let x = rand(i, 11) * size.width + sin(t * 0.7) * 12
                let y = (rand(i, 12) * size.height + t * speed)
                    .truncatingRemainder(dividingBy: size.height + 30) - 20
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x - 2.5, y: y + 14))
                ctx.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 1.4)
            }
        case .snow:
            for i in 0..<60 {
                let speed = 55.0 + rand(i, 13) * 55.0
                let x = rand(i, 14) * size.width + sin(t * (0.6 + rand(i, 15)) + Double(i)) * 22
                let y = (rand(i, 16) * size.height + t * speed)
                    .truncatingRemainder(dividingBy: size.height + 12) - 8
                let s = 2.5 + rand(i, 17) * 3.0
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                         with: .color(.white.opacity(0.8)))
            }
        case .none:
            break
        }
    }
}
