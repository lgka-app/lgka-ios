import SwiftUI
import LGKACore

/// Home hub — mirrors home_screen.dart: weather card, substitution cards,
/// schedule class card, upcoming events; toolbar: news / sick note / settings.
@MainActor
final class HomeModel: ObservableObject {
    @Published var today: SchoolAPI.SubPlan?
    @Published var tomorrow: SchoolAPI.SubPlan?
    @Published var subError = false
    @Published var subLoading = true

    @Published var weather: SchoolAPI.WeatherData?
    @Published var weatherError = false

    @Published var schedules: [SchoolAPI.Schedule] = []
    @Published var scheduleError = false
    @Published var scheduleLoading = true

    @Published var events: [SchoolAPI.Event] = []
    @Published var eventsError = false
    @Published var eventsLoading = true

    func loadAll() async {
        async let a: () = loadSubstitution()
        async let b: () = loadWeather()
        async let c: () = loadSchedules()
        async let d: () = loadEvents()
        _ = await (a, b, c, d)
    }

    func loadSubstitution() async {
        subLoading = today == nil && tomorrow == nil
        do {
            async let t = SchoolAPI.substitutionPlan(today: true)
            async let m = SchoolAPI.substitutionPlan(today: false)
            today = try await t
            tomorrow = try await m
            subError = false
        } catch {
            if today == nil { subError = true }
        }
        subLoading = false
    }

    func loadWeather() async {
        do {
            weather = try await SchoolAPI.weather()
            weatherError = false
        } catch {
            if weather == nil { weatherError = true }
        }
    }

    func loadSchedules() async {
        scheduleLoading = schedules.isEmpty
        do {
            schedules = try await SchoolAPI.schedules()
            scheduleError = false
        } catch {
            if schedules.isEmpty { scheduleError = true }
        }
        scheduleLoading = false
    }

    func loadEvents() async {
        eventsLoading = events.isEmpty
        do {
            events = try await SchoolAPI.events()
            eventsError = false
        } catch {
            if events.isEmpty { eventsError = true }
        }
        eventsLoading = false
    }
}

struct HomeScreen: View {
    @EnvironmentObject private var prefs: Prefs
    @StateObject private var model = HomeModel()
    @State private var showSettings = false
    @State private var showClassDialog = false
    @State private var classInput = ""
    @State private var pdfDestination: PdfDestination?
    @State private var scheduleLoadingOverlay = false
    @State private var path: [HomeRoute] = []

    enum HomeRoute: Hashable {
        case weather, news, krankmeldungInfo, krankmeldungForm, bugReport
    }

    struct PdfDestination: Identifiable {
        let id = UUID()
        let fileUrl: URL
        let title: String
        let targetPage: Int?
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    weatherSection
                    sectionHeader(L.s("substitutionPlan")).padding(.top, 28)
                    substitutionSection
                    sectionHeader(L.s("schedule")).padding(.top, 28)
                    scheduleSection
                    sectionHeader(L.s("termine")).padding(.top, 28)
                    eventsSection
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .themeBg()
            .navigationTitle(L.s("appTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { Haptics.light(); path.append(.news) } label: {
                        Image(systemName: "newspaper")
                    }
                    Button { Haptics.light(); openKrankmeldung() } label: {
                        Image(systemName: "cross.case")
                    }
                    Button { Haptics.light(); showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .weather: WeatherPageScreen(model: model)
                case .news: NewsListScreen()
                case .krankmeldungInfo:
                    KrankmeldungInfoScreen { path.append(.krankmeldungForm) }
                case .krankmeldungForm:
                    WebScreen(url: "https://drkrankmeldung.lgka-online.de",
                              title: L.s("krankmeldung"))
                case .bugReport: BugReportScreen()
                }
            }
            .refreshable {
                Haptics.medium()
                await model.loadAll()
            }
            .task { await model.loadAll() }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(onBugReport: {
                    showSettings = false
                    path.append(.bugReport)
                })
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(item: $pdfDestination) { dest in
                PdfViewerScreen(fileUrl: dest.fileUrl, title: dest.title,
                                targetPage: dest.targetPage)
            }
            .alert(L.s("setClassTitle"), isPresented: $showClassDialog) {
                TextField(L.s("searchHint"), text: $classInput)
                    .textInputAutocapitalization(.never)
                Button(L.s("cancel"), role: .cancel) {}
                Button(L.s("setClassButton")) {
                    let cls = classInput.trimmingCharacters(in: .whitespaces).lowercased()
                    if !cls.isEmpty { prefs.selectedScheduleClass = cls }
                }
            }
            .overlay {
                if scheduleLoadingOverlay {
                    ProgressView(L.s("loadingSchedule"))
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.callout.weight(.bold))
            .padding(.bottom, 12)
    }

    // ── Weather card ────────────────────────────────────────────────────────

    @ViewBuilder private var weatherSection: some View {
        if let w = model.weather {
            Button {
                Haptics.medium()
                path.append(.weather)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: Wmo.symbol(w.code, isDay: w.isDay))
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("\(Int(w.temp.rounded()))°")
                                .font(.callout.weight(.bold))
                            Text(L.wmo(w.code))
                                .font(.callout.weight(.semibold))
                                .opacity(0.9)
                                .lineLimit(1)
                        }
                        Text(feelsLikeLine(w))
                            .font(.caption.weight(.semibold))
                            .opacity(0.75)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.38), radius: 6)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 18)
                .frame(height: 76)
                .frame(maxWidth: .infinity)
                .background(WeatherScene.gradient(w.code, isDay: w.isDay))
                .overlay(LinearGradient(colors: [.black.opacity(0.07), .black.opacity(0.16)],
                                        startPoint: .top, endPoint: .bottom))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        } else if model.weatherError {
            HStack(spacing: 14) {
                Image(systemName: "cloud.slash").foregroundStyle(.secondary)
                Text(L.s("weatherDataNotAvailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { Haptics.light(); Task { await model.loadWeather() } } label: {
                    Image(systemName: "arrow.clockwise").font(.footnote)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 76)
            .surfaceCard()
        } else {
            SkeletonCard()
        }
    }

    private func feelsLikeLine(_ w: SchoolAPI.WeatherData) -> String {
        let feels = Int(w.feelsLike.rounded())
        if let today = w.daily.first {
            let hi = Int(today.tempMax.rounded()), lo = Int(today.tempMin.rounded())
            return L.isGerman
                ? "Gefühlt \(feels)°  ·  \(lo)° – \(hi)°"
                : "Feels like \(feels)°  ·  \(lo)° – \(hi)°"
        }
        return L.isGerman
            ? "Gefühlt \(feels)°  ·  \(w.humidity)% Luftfeuchte"
            : "Feels like \(feels)°  ·  \(w.humidity)% humidity"
    }

    // ── Substitution cards ──────────────────────────────────────────────────

    @ViewBuilder private var substitutionSection: some View {
        if model.subLoading {
            VStack(spacing: 12) { SkeletonCard(); SkeletonCard() }
        } else if model.subError {
            VStack(spacing: 12) {
                Image(systemName: "cloud.slash")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary.opacity(0.6))
                Text(L.s("serverConnectionFailed")).font(.subheadline.weight(.semibold))
                Text(L.s("serverConnectionHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(L.s("tryAgain")) {
                    Haptics.light()
                    Task { await model.loadSubstitution() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .surfaceCard()
        } else {
            VStack(spacing: 12) {
                subCard(model.today, isToday: true)
                subCard(model.tomorrow, isToday: false)
            }
        }
    }

    @ViewBuilder private func subCard(_ plan: SchoolAPI.SubPlan?, isToday: Bool) -> some View {
        let canOpen = plan?.canDisplay ?? false
        let weekday = displayWeekday(plan?.weekday)
        let title = canOpen ? weekday : L.s("noInfoYet")
        Button {
            guard let plan, let file = plan.fileUrl, canOpen else { return }
            Haptics.medium()
            pdfDestination = PdfDestination(fileUrl: file, title: weekday, targetPage: nil)
        } label: {
            HStack(spacing: 14) {
                IconSquare(systemName: "calendar", alpha: canOpen ? 0.12 : 0.08)
                    .opacity(canOpen ? 1 : 0.5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(canOpen ? .primary : Color.primary.opacity(0.35))
                    if canOpen, let date = plan?.planDate {
                        Text(date).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if canOpen {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 76)
            .frame(maxWidth: .infinity)
            .surfaceCard()
            .opacity(canOpen ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!canOpen)
    }

    private func displayWeekday(_ weekday: String?) -> String {
        guard let weekday, weekday != "weekend", !weekday.isEmpty else {
            return L.s("noInfoYet")
        }
        if !L.isGerman {
            let map = ["Montag": "Monday", "Dienstag": "Tuesday", "Mittwoch": "Wednesday",
                       "Donnerstag": "Thursday", "Freitag": "Friday",
                       "Samstag": "Saturday", "Sonntag": "Sunday"]
            return map[weekday] ?? weekday
        }
        return weekday
    }

    // ── Schedule card ───────────────────────────────────────────────────────

    @ViewBuilder private var scheduleSection: some View {
        if model.scheduleLoading {
            SkeletonCard()
        } else if model.scheduleError {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(L.s("serverConnectionFailed"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button { Haptics.light(); Task { await model.loadSchedules() } } label: {
                    Image(systemName: "arrow.clockwise").font(.footnote)
                }
            }
            .padding(20)
            .surfaceCard()
        } else if model.schedules.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "clock").foregroundStyle(.secondary.opacity(0.4))
                Text(L.s("noSchedulesAvailable"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(20)
            .surfaceCard()
        } else if prefs.selectedScheduleClass.isEmpty {
            homeCard(icon: "graduationcap",
                     title: L.s("scheduleNoClassTitle"),
                     subtitle: L.s("scheduleNoClassSub")) {
                Haptics.light()
                classInput = ""
                showClassDialog = true
            }
        } else {
            let cls = prefs.selectedScheduleClass
            let half = preferredGroup.first?.halbjahr == "1. Halbjahr"
                ? L.s("firstSemester") : L.s("secondSemester")
            homeCard(icon: "tablecells",
                     title: formatClassName(cls),
                     subtitle: half) {
                Haptics.medium()
                openSchedule(for: cls)
            }
            .contextMenu {
                Button(L.s("setClassTitle")) {
                    classInput = cls
                    showClassDialog = true
                }
            }
        }
    }

    private func homeCard(icon: String, title: String, subtitle: String,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconSquare(systemName: icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 18)
            .frame(height: 76)
            .frame(maxWidth: .infinity)
            .surfaceCard()
        }
        .buttonStyle(.plain)
    }

    /// Prefer 2. Halbjahr, mirroring the provider's active-group logic.
    private var preferredGroup: [SchoolAPI.Schedule] {
        let second = model.schedules.filter { $0.halbjahr == "2. Halbjahr" }
        return second.isEmpty
            ? model.schedules.filter { $0.halbjahr == "1. Halbjahr" }
            : second
    }

    private func formatClassName(_ cls: String) -> String {
        if cls == "j11" { return L.s("jahrgang11") }
        if cls == "j12" { return L.s("jahrgang12") }
        let name = cls.prefix(1).uppercased() + cls.dropFirst()
        return L.isGerman ? "Klasse \(name)" : "Class \(name)"
    }

    private func openSchedule(for cls: String) {
        let isJahrgang = cls.hasPrefix("j")
        let group = preferredGroup
        let target = isJahrgang
            ? group.first(where: { $0.gradeLevel == "J11/J12" }) ?? group.first
            : group.first(where: { $0.gradeLevel == "Klassen 5-10" }) ?? group.first
        guard let target else { return }
        let half = target.halbjahr == "1. Halbjahr"
            ? L.s("firstSemester") : L.s("secondSemester")

        scheduleLoadingOverlay = true
        Task {
            defer { scheduleLoadingOverlay = false }
            do {
                let (file, index) = try await SchoolAPI.schedulePdf(target)
                let page = index[cls] // display page (pageIndex + 2)
                pdfDestination = PdfDestination(
                    fileUrl: file,
                    title: "\(formatClassName(cls)) – \(half)",
                    targetPage: page)
            } catch {
                // parity: SnackBar error — approximated by silent fail + retry via card
            }
        }
    }

    // ── Events ──────────────────────────────────────────────────────────────

    @ViewBuilder private var eventsSection: some View {
        if model.eventsLoading {
            VStack(spacing: 12) { ForEach(0..<4, id: \.self) { _ in SkeletonCard() } }
        } else if model.eventsError && model.events.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(L.s("serverConnectionFailed"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button { Haptics.light(); Task { await model.loadEvents() } } label: {
                    Image(systemName: "arrow.clockwise").font(.footnote)
                }
            }
            .padding(20)
            .surfaceCard()
        } else if model.events.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "calendar").foregroundStyle(.secondary.opacity(0.4))
                Text(L.s("noEventsAvailable"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(20)
            .surfaceCard()
        } else {
            VStack(spacing: 12) {
                ForEach(model.events.prefix(4)) { event in
                    HStack(spacing: 14) {
                        IconSquare(systemName: "calendar")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(eventSubtitle(event))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 76)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .surfaceCard()
                }
            }
        }
    }

    private func eventSubtitle(_ event: SchoolAPI.Event) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: event.date) else { return event.time ?? "" }
        let out = DateFormatter()
        out.locale = Locale(identifier: L.isGerman ? "de_DE" : "en_US")
        out.dateFormat = "EEE, d. MMMM"
        let base = out.string(from: date)
        return event.time != nil ? "\(base) · \(event.time!)" : base
    }

    private func openKrankmeldung() {
        if prefs.krankmeldungInfoShown {
            path.append(.krankmeldungForm)
        } else {
            path.append(.krankmeldungInfo)
        }
    }
}
