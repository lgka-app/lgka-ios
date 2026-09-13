import SwiftUI
import PDFKit
import LGKACore

/// Home hub — mirrors home_screen.dart: weather card, substitution cards,
/// schedule class card, upcoming events; toolbar: news / sick note / settings.
struct HomeScreen: View {
    @Environment(Prefs.self) private var prefs
    @Environment(HomeModel.self) private var model
    @Environment(\.appAccent) private var accent
    @State private var showSettings = false
    @State private var showClassDialog = false
    @State private var classInput = ""
    @State private var pdfDestination: PdfDestination?
    /// Type-erased so both HomeRoute pushes and value links (news articles) resolve.
    @State private var path = NavigationPath()
    @State private var scheduleUnavailable: String?
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize = 40

    enum HomeRoute: Hashable {
        case weather, news, krankmeldungInfo, bugReport
        /// Any web page in the app's own web screen (privacy, legal notice) — pushed like the bug report.
        case web(url: String, title: String)
    }

    struct PdfDestination: Identifiable {
        let id = UUID()
        let fileUrl: URL
        let title: String
        /// 0-based page index to open on.
        let targetPage: Int?
        var schedule: ScheduleItem? = nil
        /// class → real 1-based page (API contract).
        var classIndex: [String: Int] = [:]
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section { weatherSection }
                Section(L.s("substitutionPlan")) { substitutionSection }
                Section(L.s("schedule")) { scheduleSection }
                Section(L.s("termine")) { eventsSection }
            }
            .listStyle(.insetGrouped)
            .readableWidth()
            .background(Color.appBackground)
            .navigationTitle(L.s("appTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { Haptics.light(); path.append(HomeRoute.news) } label: {
                        Label(L.s("news"), systemImage: "newspaper")
                    }
                    .accessibilityIdentifier("home.news")
                    Button { Haptics.light(); openKrankmeldung() } label: {
                        Label(L.s("krankmeldung"), systemImage: "cross.case")
                    }
                    .accessibilityIdentifier("home.sick")
                    Button { Haptics.light(); showSettings = true } label: {
                        Label(L.s("settings"), systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("home.settings")
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .weather: WeatherPageScreen()
                case .news: NewsListScreen()
                case .krankmeldungInfo:
                    KrankmeldungInfoScreen {
                        path.removeLast()
                        HomeScreen.openKrankmeldungForm()
                    }
                case .bugReport: BugReportScreen()
                case .web(let url, let title): WebScreen(url: url, title: title)
                }
            }
            .refreshable {
                Haptics.medium()
                await model.sync()
            }
            // the system back button and the swipe-back gesture have no haptic of their own
            .onChange(of: path.count) { old, new in if new < old { Haptics.light() } }
            .task { await model.bootstrap() }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(onBugReport: {
                    showSettings = false
                    path.append(HomeRoute.bugReport)
                }, onOpenWeb: { url, title in
                    showSettings = false
                    path.append(HomeRoute.web(url: url, title: title))
                })
                .adaptiveSheetSizing()
            }
            .fullScreenCover(item: $pdfDestination) { dest in
                PdfViewerScreen(fileUrl: dest.fileUrl, title: dest.title,
                                targetPage: dest.targetPage,
                                schedule: dest.schedule,
                                classIndex: dest.classIndex)
            }
            .alert(scheduleUnavailable ?? "", isPresented: .init(
                get: { scheduleUnavailable != nil },
                set: { if !$0 { scheduleUnavailable = nil } })) {
                Button("OK", role: .cancel) { Haptics.light() }
            }
            .alert(L.s("setClassTitle"), isPresented: $showClassDialog) {
                TextField(L.s("searchHint"), text: $classInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(L.s("cancel"), role: .cancel) { Haptics.light() }
                Button(L.s("setClassButton")) {
                    Haptics.medium()
                    let cls = classInput.trimmingCharacters(in: .whitespaces).lowercased()
                    if !cls.isEmpty { prefs.selectedScheduleClass = cls }
                }
            }
        }
    }

    // ── Weather card ────────────────────────────────────────────────────────

    @ViewBuilder private var weatherSection: some View {
        if let w = model.weather {
            Button {
                Haptics.medium()
                path.append(HomeRoute.weather)
            } label: {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L.s("city"))
                            .font(.footnote.weight(.semibold))
                            .opacity(0.85)
                        Text("\(Int(w.current.temp.rounded()))°")
                            .font(.system(size: heroSize, weight: .medium, design: .rounded))
                        Text(Wmo.description(w.current.weatherCode))
                            .font(.footnote.weight(.medium))
                            .opacity(0.9)
                            .lineLimit(1)
                        Text(feelsLikeLine(w))
                            .font(.caption2.weight(.semibold))
                            .opacity(0.8)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        Image(systemName: Wmo.symbol(w.current.weatherCode, isDay: w.current.isDay))
                            .font(.title)
                            .symbolRenderingMode(.multicolor)
                        if let today = w.daily.first {
                            Text(L.f("highLow", Int(today.tempMax.rounded()), Int(today.tempMin.rounded())))
                                .font(.caption.weight(.medium))
                                .opacity(0.9)
                        }
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 4)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                // The whole card is the hit target, not only the glyphs.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(
                WeatherSkyView(code: w.current.weatherCode, isDay: w.current.isDay, particles: false)
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.18)],
                                            startPoint: .top, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.f("a11y.weatherCard", Wmo.description(w.current.weatherCode), Int(w.current.temp.rounded())))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("home.weather")
        } else if model.weatherError {
            HStack(spacing: 14) {
                Image(systemName: "cloud.slash").foregroundStyle(.secondary)
                Text(L.s("weatherDataNotAvailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                retryButton { await model.sync(only: [.weather]) }
            }
            .frame(minHeight: 56)
        } else {
            skeletonRow
        }
    }

    private func retryButton(_ action: @escaping @MainActor () async -> Void) -> some View {
        Button { Haptics.light(); Task { await action() } } label: {
            Image(systemName: "arrow.clockwise").font(.footnote)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(L.s("a11y.retry"))
    }

    private var skeletonRow: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("Placeholder Title").font(.callout)
                Text("Placeholder sub").font(.caption)
            }
            Spacer()
        }
        .redacted(reason: .placeholder)
        .padding(.vertical, 8)
        .accessibilityLabel(L.s("loading"))
    }

    private func feelsLikeLine(_ w: WeatherData) -> String {
        let feels = Int(w.current.feelsLike.rounded())
        if let today = w.daily.first {
            return L.f("feelsLike.range", feels, Int(today.tempMin.rounded()), Int(today.tempMax.rounded()))
        }
        return L.f("feelsLike.humidity", feels, w.current.humidity)
    }

    // ── Substitution cards ──────────────────────────────────────────────────

    @ViewBuilder private var substitutionSection: some View {
        if model.subLoading {
            skeletonRow
            skeletonRow
        } else if model.subError {
            VStack(spacing: 12) {
                Image(systemName: "cloud.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary.opacity(0.6))
                    .accessibilityHidden(true)
                Text(L.s("serverConnectionFailed")).font(.subheadline.weight(.semibold))
                Text(L.s("serverConnectionHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(L.s("tryAgain")) {
                    Haptics.light()
                    Task { await model.sync(only: [.substitutions]) }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
            subCard(model.today, isToday: true).accessibilityIdentifier("home.plan.today")
            subCard(model.tomorrow, isToday: false).accessibilityIdentifier("home.plan.tomorrow")
        }
    }

    @ViewBuilder private func subCard(_ plan: DayPlan?, isToday: Bool) -> some View {
        if plan == nil && !model.subLoading && !model.subError {
            // per-card failure (home_screen per-day retry parity)
            Button {
                Haptics.medium()
                Task { await model.sync(only: [.substitutions]) }
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.s("errorLoading"))
            .accessibilityHint(L.s("a11y.retry"))
        } else {
            subCardContent(plan)
        }
    }

    @ViewBuilder private func subCardContent(_ plan: DayPlan?) -> some View {
        let canOpen = plan?.canDisplay ?? false
        let weekday = displayWeekday(plan?.meta.weekday)
        let title = canOpen ? weekday : L.s("noInfoYet")
        let subtitle: String? = {
            guard canOpen, let plan else { return nil }
            return "\(plan.meta.date) · " + String(localized: "substitutions.count \(plan.plan.entries.count)")
        }()
        Button {
            guard let plan, canOpen else { return }
            Haptics.medium()
            Task {
                // the mirrored PDF arrived with the sync; a missing file is fetched once
                guard let file = try? await model.pdfURL(for: plan.pdf) else { return }
                pdfDestination = PdfDestination(fileUrl: DebugPdf.padded(file), title: weekday, targetPage: nil)
            }
        } label: {
            HStack(spacing: 14) {
                IconSquare(systemName: "calendar", alpha: canOpen ? 0.12 : 0.08)
                    .opacity(canOpen ? 1 : 0.5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(canOpen ? .primary : Color.primary.opacity(0.35))
                    if let subtitle {
                        Text(subtitle)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canOpen)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.f("a11y.subPlan", title, subtitle ?? ""))
        .accessibilityAddTraits(canOpen ? .isButton : [])
    }

    private func displayWeekday(_ weekday: String?) -> String {
        guard let weekday, weekday != "weekend", !weekday.isEmpty else {
            return L.s("noInfoYet")
        }
        return L.weekday(weekday)
    }

    // ── Schedule card ───────────────────────────────────────────────────────

    @ViewBuilder private var scheduleSection: some View {
        if model.scheduleLoading {
            skeletonRow
        } else if model.scheduleError {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.secondary.opacity(0.5))
                    .accessibilityHidden(true)
                Text(L.s("serverConnectionFailed"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                retryButton { await model.sync(only: [.schedules]) }
            }
            .padding(.vertical, 8)
        } else if preferredGroup.isEmpty {
            // also when no item names a known Halbjahr: a class card would open nothing
            HStack(spacing: 12) {
                Image(systemName: "clock").foregroundStyle(.secondary.opacity(0.4))
                    .accessibilityHidden(true)
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
                     title: L.className(cls),
                     subtitle: half) {
                openSchedule(for: cls)
            }
            .accessibilityIdentifier("home.schedule")
            .contextMenu {
                Button(L.s("setClassTitle"), systemImage: "pencil") {
                    Haptics.light()
                    classInput = cls
                    showClassDialog = true
                }
            }
        }
    }

    private func homeCard(icon: String, title: String, subtitle: String,
                          action: @escaping () -> Void) -> some View {
        Button { Haptics.medium(); action() } label: {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }

    private var preferredGroup: [ScheduleItem] { model.preferredGroup }

    private func openSchedule(for cls: String) {
        // the PDF whose discovered grades contain the class (5-10, J11, J12, a future J13, …)
        guard let target = HomeScreen.schedule(for: cls, in: preferredGroup) else { return }
        let half = target.halbjahr == "1. Halbjahr"
            ? L.s("firstSemester") : L.s("secondSemester")
        guard target.available, let pdf = target.pdf else {
            // home_screen SnackBar parity: the school has not published this PDF yet
            scheduleUnavailable = L.f("scheduleNotAvailable", half)
            return
        }

        // opens straight away like the substitution cards: the PDF is already on disk
        Task {
            do {
                let file = try await model.pdfURL(for: pdf)
                pdfDestination = PdfDestination(
                    fileUrl: file,
                    title: L.className(cls), // pdf_viewer header: class only
                    targetPage: target.pageIndex(forClass: cls),
                    schedule: target,
                    classIndex: target.classIndex)
            } catch {
                scheduleUnavailable = L.f("scheduleNotAvailable", half)
            }
        }
    }

    /// The schedule PDF for a class: by discovered grades first, then by the
    /// gradeLevel label, then the first available PDF.
    static func schedule(for cls: String, in group: [ScheduleItem]) -> ScheduleItem? {
        if let exact = group.first(where: { $0.covers(cls) }) { return exact }
        let jahrgang = (ScheduleGrades.gradeOf(cls) ?? 0) >= 11
        return group.first(where: { jahrgang ? $0.grades.contains(where: { $0 >= 11 }) : $0.grades.contains(where: { $0 <= 10 }) })
            ?? group.first(where: { jahrgang ? $0.gradeLevel == "J11/J12" : $0.gradeLevel == "Klassen 5-10" })
            ?? group.first
    }

    // ── Events ──────────────────────────────────────────────────────────────

    @ViewBuilder private var eventsSection: some View {
        if model.eventsLoading {
            ForEach(0..<4, id: \.self) { _ in skeletonRow }
        } else if model.eventsError && model.events.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary.opacity(0.5))
                    .accessibilityHidden(true)
                Text(L.s("serverConnectionFailed"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                retryButton { await model.sync(only: [.events]) }
            }
            .padding(.vertical, 8)
        } else if model.events.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "calendar").foregroundStyle(.secondary.opacity(0.4))
                    .accessibilityHidden(true)
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
                            .lineLimit(2)
                        Text(eventSubtitle(event))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                .accessibilityIdentifier("home.event")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L.f("a11y.event", eventSubtitle(event), event.title))
            }
        }
    }

    private func dateTile(_ iso: String) -> some View {
        let date = LocalDate.parse(iso)
        let day = date.map { Calendar.current.component(.day, from: $0) } ?? 0
        let month = date?.formatted(.dateTime.month(.abbreviated)) ?? ""
        return VStack(spacing: 0) {
            Text("\(day)").font(.title3.weight(.bold)).foregroundStyle(accent)
            Text(month).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(width: 44, height: 44)
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }

    private func eventSubtitle(_ event: SchoolEvent) -> String {
        guard let date = LocalDate.parse(event.date) else { return event.time ?? "" }
        let base = date.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
        if let time = event.time { return "\(base) · \(time)" }
        return base
    }

    private func openKrankmeldung() {
        if prefs.krankmeldungInfoShown {
            HomeScreen.openKrankmeldungForm()
        } else {
            path.append(HomeRoute.krankmeldungInfo)
        }
    }

    /// The Krankmeldung form is the one page that opens in the user's real browser.
    static func openKrankmeldungForm() {
        guard let url = URL(string: "https://drkrankmeldung.lgka-online.de") else { return }
        Task { @MainActor in await UIApplication.shared.open(url) }
    }
}

/// Debug builds only: `LGKA_DEBUG_SUB_PAGES=n` pads a substitution PDF to n pages
/// (repeating its own pages) to check how the viewer handles long plans.
enum DebugPdf {
    static func padded(_ file: URL) -> URL {
        #if DEBUG
        guard let n = ProcessInfo.processInfo.environment["LGKA_DEBUG_SUB_PAGES"].flatMap(Int.init), n > 1,
              let doc = PDFDocument(url: file), doc.pageCount > 0 else { return file }
        let out = PDFDocument()
        while out.pageCount < n {
            for i in 0..<doc.pageCount where out.pageCount < n {
                if let page = doc.page(at: i)?.copy() as? PDFPage { out.insert(page, at: out.pageCount) }
            }
        }
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("debug_substitution_\(n)_pages.pdf")
        return out.write(to: dest) ? dest : file
        #else
        return file
        #endif
    }
}
