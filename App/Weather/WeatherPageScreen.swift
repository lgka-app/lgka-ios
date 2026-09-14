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

    /// The info button's panel naming where the weather comes from.
    @State private var showSource = false

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
        .overlay(alignment: .top) {
            if showSource, let w = model.weather {
                sourcePanel(w)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle(L.s("weatherPageTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if model.weather != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.light()
                        withAnimation(.spring(duration: 0.35, bounce: 0.2)) { showSource.toggle() }
                    } label: {
                        Image(systemName: showSource ? "info.circle.fill" : "info.circle")
                    }
                    .accessibilityLabel(L.s("weather.sourceInfo"))
                    .accessibilityIdentifier("weather.sourceInfo")
                }
            }
        }
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

    /// Where the numbers come from: the school's rooftop station (when it is healthy) or Open-Meteo for
    /// the current values, Open-Meteo for the forecast.
    private func sourcePanel(_ w: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.s("weather.sourceTitle"))
                .font(.subheadline.weight(.semibold))
            Label(w.source == .school ? L.s("weather.sourceSchool") : L.s("weather.sourceCurrentOpenMeteo"),
                  systemImage: w.source == .school ? "building.2" : "cloud.sun")
            Label(L.s("weather.sourceForecast"), systemImage: "calendar")
            if let url = URL(string: "https://open-meteo.com/") {
                Button {
                    Haptics.light()
                    Task { @MainActor in await UIApplication.shared.open(url) }
                } label: {
                    Label("open-meteo.com", systemImage: "arrow.up.right.square")
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .font(.footnote)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .environment(\.colorScheme, .dark)
        .readableWidth()
        .onTapGesture {
            Haptics.light()
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) { showSource = false }
        }
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
