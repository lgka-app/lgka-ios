import SwiftUI

/// Weather — Apple-Weather-style: full-bleed animated sky, big hero
/// typography, standard-material cards scrolling over the scene. The cards
/// are content, so they use standard materials, not Liquid Glass (HIG:
/// "Don't use Liquid Glass in the content layer").
struct WeatherPageScreen: View {
    @Environment(HomeModel.self) private var model
    @Environment(\.appAccent) private var accent
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize = 96

    #if DEBUG
    /// Debug builds only: preview any sky animation regardless of live conditions.
    @State private var preview: SkyPreview?
    @State private var showPreviewMenu = false

    struct SkyPreview: Hashable {
        let label: String
        let code: Int
        let isDay: Bool
    }

    static let previews: [SkyPreview] = [
        .init(label: "Klar (Tag)", code: 0, isDay: true),
        .init(label: "Klar (Nacht)", code: 0, isDay: false),
        .init(label: "Teilweise bewölkt", code: 2, isDay: true),
        .init(label: "Bedeckt", code: 3, isDay: true),
        .init(label: "Nebel", code: 45, isDay: true),
        .init(label: "Regen (Tag)", code: 63, isDay: true),
        .init(label: "Regen (Nacht)", code: 63, isDay: false),
        .init(label: "Gewitter", code: 95, isDay: true),
        .init(label: "Schnee (Tag)", code: 73, isDay: true),
        .init(label: "Schnee (Nacht)", code: 73, isDay: false),
    ]
    #endif

    private var skyCode: Int? {
        #if DEBUG
        preview?.code
        #else
        nil
        #endif
    }

    private var skyIsDay: Bool? {
        #if DEBUG
        preview?.isDay
        #else
        nil
        #endif
    }

    var body: some View {
        ZStack {
            if let w = model.weather {
                WeatherSkyView(code: skyCode ?? w.code,
                               isDay: skyIsDay ?? w.isDay,
                               particles: true)
                    .id("\(skyCode ?? w.code)-\(skyIsDay ?? w.isDay)")
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
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
        .navigationTitle(L.s("weatherPageTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #if DEBUG
        .confirmationDialog(L.s("a11y.skyPreview"), isPresented: $showPreviewMenu, titleVisibility: .visible) {
            Button(L.s("live")) { preview = nil }
            ForEach(Self.previews, id: \.self) { option in
                Button(option.label) { preview = option }
            }
        }
        #endif
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
                if let url = URL(string: "https://open-meteo.com/") {
                    Link(L.s("weatherAttribution"), destination: url)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.vertical, 12)
                }
            }
            .readableWidth()
            .padding(.horizontal, 16)
        }
        .accessibilityIdentifier("weather.page")
    }

    // ── Hero ────────────────────────────────────────────────────────────────

    private func hero(_ w: SchoolAPI.WeatherData) -> some View {
        VStack(spacing: 2) {
            Text(L.s("city"))
                .font(.title2.weight(.medium))
            Text("\(Int(w.temp.rounded()))°")
                .font(.system(size: heroSize, weight: .thin, design: .rounded))
                .padding(.leading, 24) // optically center over the degree sign
            Text(Wmo.description(w.code))
                .font(.callout.weight(.medium))
                .opacity(0.9)
            if let today = w.daily.first {
                Text(L.f("highLow", Int(today.tempMax.rounded()), Int(today.tempMin.rounded())))
                    .font(.callout.weight(.medium))
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 8)
        .accessibilityElement(children: .combine)
        #if DEBUG
        .onLongPressGesture { showPreviewMenu = true } // debug-only sky preview, no visible control
        #endif
    }

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

    private func hourlyCard(_ w: SchoolAPI.WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("clock", L.s("hourlyForecastLabel"))
            Divider().overlay(.white.opacity(0.2))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(w.hourly) { h in
                        VStack(spacing: 8) {
                            Text(h.time)
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
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(L.f("a11y.hour", h.time, Int(h.temp.rounded()), Wmo.description(h.code)))
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

    private func dailyCard(_ w: SchoolAPI.WeatherData) -> some View {
        let weekMin = w.daily.map(\.tempMin).min() ?? 0
        let weekMax = w.daily.map(\.tempMax).max() ?? 1
        let span = max(weekMax - weekMin, 1)

        return VStack(alignment: .leading, spacing: 4) {
            cardHeader("calendar", L.s("threeDayForecastLabel"))
            ForEach(w.daily) { d in
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L.f("a11y.day", dayLabel(d.date), Wmo.description(d.code),
                                        Int(d.tempMax.rounded()), Int(d.tempMin.rounded())))
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(cardBackground(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private func statsGrid(_ w: SchoolAPI.WeatherData) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
                  spacing: 14) {
            statTile("humidity", L.s("weatherHumidityShort"), "\(w.humidity) %")
            statTile("wind", L.s("weatherWindShort"), "\(Int(w.windSpeed.rounded())) km/h")
            statTile("gauge.with.needle", L.s("pressure"), "\(w.pressure) hPa")
            statTile("sun.max.fill", L.s("uvIndex"),
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
