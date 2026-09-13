import SwiftUI
import LGKACore

/// Weather — Apple-Weather-style: full-bleed animated sky, big hero
/// typography, standard-material cards scrolling over the scene. The cards
/// are content, so they use standard materials, not Liquid Glass (HIG:
/// "Don't use Liquid Glass in the content layer").
struct WeatherPageScreen: View {
    @Environment(HomeModel.self) private var model
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
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
                WeatherSkyView(code: skyCode ?? w.current.weatherCode,
                               isDay: skyIsDay ?? w.current.isDay,
                               particles: true)
                    .id("\(skyCode ?? w.current.weatherCode)-\(skyIsDay ?? w.current.isDay)")
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                content(w)
            } else if model.weatherError {
                ContentUnavailableView {
                    Label(L.s("weatherDataNotAvailable"), systemImage: "cloud.slash")
                } description: {
                    Text(L.s("checkInternetConnection"))
                } actions: {
                    Button(L.s("tryAgain")) { Haptics.light(); Task { await model.sync(only: [.weather]) } }
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
            Button(L.s("live")) { Haptics.light(); preview = nil }
            ForEach(Self.previews, id: \.self) { option in
                Button(option.label) { Haptics.light(); preview = option }
            }
        }
        #endif
        .refreshable { Haptics.medium(); await model.sync(only: [.weather]) }
    }

    private func content(_ w: WeatherData) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                hero(w)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                if !model.hourly.isEmpty { hourlyCard(model.hourly) }
                if !w.daily.isEmpty { dailyCard(w) }
                statsGrid(w)
                attribution(w)
            }
            .readableWidth()
            .padding(.horizontal, 16)
        }
        .accessibilityIdentifier("weather.page")
    }

    // ── Hero ────────────────────────────────────────────────────────────────

    private func hero(_ w: WeatherData) -> some View {
        VStack(spacing: 2) {
            Text(L.s("city"))
                .font(.title2.weight(.medium))
            Text("\(Int(w.current.temp.rounded()))°")
                .font(.system(size: heroSize, weight: .thin, design: .rounded))
                .padding(.leading, 24) // optically center over the degree sign
            Text(Wmo.description(w.current.weatherCode))
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

}
