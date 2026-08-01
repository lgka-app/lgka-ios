import SwiftUI
import LGKACore

/// Home hub — mirrors home_screen.dart: weather card, substitution cards,
/// schedule class card, upcoming events; toolbar: news / sick note / settings.
@MainActor
final class HomeModel: ObservableObject {
    static let shared = HomeModel()

    @Published var newsList: [NewsParser.Metadata]?
    @Published var newsFailed = false
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

    private var bootstrapped = false

    /// Startup preload, mirroring main.dart's _preloadData:
    /// phase 1 shows any cached data instantly, phase 2 refreshes per TTL,
    /// then news article contents are prefetched into the cache.
    func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true
        await loadAll(mode: .cacheAny)
        await loadAll(mode: .cacheFirst)
        await prefetchArticles()
    }

    func loadAll(mode: FetchMode = .cacheFirst) async {
        async let a: () = loadSubstitution(mode: mode)
        async let b: () = loadWeather(mode: mode)
        async let c: () = loadSchedules(mode: mode)
        async let d: () = loadEvents(mode: mode)
        async let e: () = loadNews(mode: mode)
        _ = await (a, b, c, d, e)
    }

    func loadNews(mode: FetchMode = .cacheFirst) async {
        do {
            newsList = try await SchoolAPI.newsList(mode: mode)
            newsFailed = false
        } catch {
            if newsList == nil { newsFailed = true }
        }
    }

    /// Prefer 2. Halbjahr — mirrors the provider's active-group logic.
    var preferredGroup: [SchoolAPI.Schedule] {
        let second = schedules.filter { $0.halbjahr == "2. Halbjahr" }
        return second.isEmpty
            ? schedules.filter { $0.halbjahr == "1. Halbjahr" }
            : second
    }

    /// Fetch all article pages into the disk cache so detail opens instantly
    /// (the Flutter app fetches full contents up front too).
    func prefetchArticles() async {
        guard let list = newsList else { return }
        await withTaskGroup(of: Void.self) { group in
            for md in list.prefix(20) {
                group.addTask {
                    _ = try? await SchoolAPI.article(url: md.url, mode: .cacheFirst)
                }
            }
        }
    }

    func loadSubstitution(mode: FetchMode = .cacheFirst) async {
        subLoading = today == nil && tomorrow == nil
        do {
            async let t = SchoolAPI.substitutionPlan(today: true, mode: mode)
            async let m = SchoolAPI.substitutionPlan(today: false, mode: mode)
            today = try await t
            tomorrow = try await m
            subError = false
        } catch {
            if today == nil { subError = true }
        }
        subLoading = false
    }

    func loadWeather(mode: FetchMode = .cacheFirst) async {
        do {
            weather = try await SchoolAPI.weather(mode: mode)
            weatherError = false
        } catch {
            if weather == nil { weatherError = true }
        }
    }

    func loadSchedules(mode: FetchMode = .cacheFirst) async {
        scheduleLoading = schedules.isEmpty
        do {
            schedules = try await SchoolAPI.schedules(mode: mode)
            scheduleError = false
        } catch {
            if schedules.isEmpty { scheduleError = true }
        }
        scheduleLoading = false
    }

    func loadEvents(mode: FetchMode = .cacheFirst) async {
        eventsLoading = events.isEmpty
        do {
            events = try await SchoolAPI.events(mode: mode)
            eventsError = false
        } catch {
            if events.isEmpty { eventsError = true }
        }
        eventsLoading = false
    }
}

struct HomeScreen: View {
    @EnvironmentObject private var prefs: Prefs
    @ObservedObject private var model = HomeModel.shared
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
        var gradeLevel: String? = nil
    }

    @State private var scheduleUnavailable: String?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section { weatherSection }
                Section(L.s("substitutionPlan")) { substitutionSection }
                Section(L.s("schedule")) { scheduleSection }
                Section(L.s("termine")) { eventsSection }
            }
            .listStyle(.insetGrouped)
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
                              title: L.s("krankmeldung"),
                              confineToHost: "lgka-online.de")
                case .bugReport: BugReportScreen()
                }
            }
            .refreshable {
                Haptics.medium()
                await model.loadAll(mode: .refresh)
            }
            .task { await model.bootstrap() }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(onBugReport: {
                    showSettings = false
                    path.append(.bugReport)
                })
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(item: $pdfDestination) { dest in
                PdfViewerScreen(fileUrl: dest.fileUrl, title: dest.title,
                                targetPage: dest.targetPage,
                                gradeLevel: dest.gradeLevel)
            }
            .alert(scheduleUnavailable ?? "", isPresented: .init(
                get: { scheduleUnavailable != nil },
                set: { if !$0 { scheduleUnavailable = nil } })) {
                Button("OK", role: .cancel) {}
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

    // ── Weather card ────────────────────────────────────────────────────────

    @ViewBuilder private var weatherSection: some View {
        if let w = model.weather {
            Button {
                Haptics.medium()
                path.append(.weather)
            } label: {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Karlsruhe")
                            .font(.footnote.weight(.semibold))
                            .opacity(0.85)
                        Text("\(Int(w.temp.rounded()))°")
                            .font(.system(size: 40, weight: .medium))
                        Text(L.wmo(w.code))
                            .font(.footnote.weight(.medium))
                            .opacity(0.9)
                            .lineLimit(1)
                        Text(feelsLikeLine(w))
                            .font(.caption2.weight(.semibold))
                            .opacity(0.8)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Image(systemName: Wmo.symbol(w.code, isDay: w.isDay))
                            .font(.system(size: 28))
                            .symbolRenderingMode(.multicolor)
                        if let today = w.daily.first {
                            Text("H: \(Int(today.tempMax.rounded()))°  T: \(Int(today.tempMin.rounded()))°")
                                .font(.caption.weight(.medium))
                                .opacity(0.9)
                        }
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 4)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(height: 112)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(
                WeatherSkyView(code: w.code, isDay: w.isDay, particles: false)
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.18)],
                                            startPoint: .top, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: 10)))
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
            .frame(height: 56)
        } else {
            skeletonRow
        }
    }

    private var skeletonRow: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12).fill(.quaternary)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("Placeholder Title").font(.callout)
                Text("Placeholder sub").font(.caption)
            }
            Spacer()
        }
        .redacted(reason: .placeholder)
        .padding(.vertical, 8)
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
            skeletonRow
            skeletonRow
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
            .padding(.vertical, 12)
        } else {
            subCard(model.today, isToday: true)
            subCard(model.tomorrow, isToday: false)
        }
    }

    @ViewBuilder private func subCard(_ plan: SchoolAPI.SubPlan?, isToday: Bool) -> some View {
        if plan == nil && !model.subLoading && !model.subError {
            // per-card failure (home_screen per-day retry parity)
            Button {
                Haptics.medium()
                Task { await model.loadSubstitution(mode: .refresh) }
            } label: {
                HStack(spacing: 14) {
                    IconSquare(systemName: "arrow.clockwise")
                    Text(L.s("errorLoading"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote)
                        .foregroundStyle(.tint)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        } else {
            subCardContent(plan)
        }
    }

    @ViewBuilder private func subCardContent(_ plan: SchoolAPI.SubPlan?) -> some View {
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
                    if canOpen, let plan, let date = plan.planDate {
                        Text("\(date) · \(entriesLabel(plan.entries.count))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if canOpen {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .opacity(canOpen ? 1 : 0.6)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(!canOpen)
    }

    private func entriesLabel(_ count: Int) -> String {
        if L.isGerman {
            return count == 0 ? "Keine Vertretungen"
                : count == 1 ? "1 Vertretung" : "\(count) Vertretungen"
        }
        return count == 0 ? "No substitutions"
            : count == 1 ? "1 substitution" : "\(count) substitutions"
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
            skeletonRow
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
            .padding(.vertical, 8)
        } else if model.schedules.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "clock").foregroundStyle(.secondary.opacity(0.4))
                Text(L.s("noSchedulesAvailable"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
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
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var preferredGroup: [SchoolAPI.Schedule] { model.preferredGroup }

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
                    targetPage: page,
                    gradeLevel: target.gradeLevel)
            } catch {
                // home_screen SnackBar parity
                scheduleUnavailable = "\(half) \(L.s("scheduleNotAvailable"))"
            }
        }
    }

    // ── Events ──────────────────────────────────────────────────────────────

    @ViewBuilder private var eventsSection: some View {
        if model.eventsLoading {
            ForEach(0..<4, id: \.self) { _ in skeletonRow }
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
            .padding(.vertical, 8)
        } else if model.events.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "calendar").foregroundStyle(.secondary.opacity(0.4))
                Text(L.s("noEventsAvailable"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
        } else {
            ForEach(model.events.prefix(4)) { event in
                    HStack(spacing: 14) {
                        dateTile(event.date)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(eventSubtitle(event))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
        }
    }

    @Environment(\.appAccent) private var accent

    private func dateTile(_ iso: String) -> some View {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let date = df.date(from: iso)
        let day = date.map { Calendar.current.component(.day, from: $0) } ?? 0
        let out = DateFormatter()
        out.locale = Locale(identifier: L.isGerman ? "de_DE" : "en_US")
        out.dateFormat = "MMM"
        let month = date.map { out.string(from: $0) } ?? ""
        return VStack(spacing: 0) {
            Text("\(day)").font(.title3.weight(.bold)).foregroundStyle(accent)
            Text(month).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(width: 44, height: 44)
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
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
