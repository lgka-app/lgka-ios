import SwiftUI
import LGKACore

/// Home hub — mirrors home_screen.dart: weather card, substitution cards,
/// schedule class card, upcoming events; toolbar: news / sick note / settings.
struct HomeScreen: View {
    @Environment(Prefs.self) var prefs
    @Environment(HomeModel.self) var model
    @Environment(\.appAccent) var accent
    @State private var showSettings = false
    @State var showClassDialog = false
    @State var classInput = ""
    @State var pdfDestination: PdfDestination?
    /// Type-erased so both HomeRoute pushes and value links (news articles) resolve.
    @State var path = NavigationPath()
    @State var scheduleUnavailable: String?
    @ScaledMetric(relativeTo: .largeTitle) var heroSize = 40

    enum HomeRoute: Hashable {
        case weather, news, krankmeldungInfo, bugReport, customPlan
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
                        // a second tap during the pop must not pop an empty path
                        if !path.isEmpty { path.removeLast() }
                        HomeScreen.openKrankmeldungForm()
                    }
                case .bugReport: BugReportScreen()
                case .customPlan: CustomPlanHost()
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
                    let query = ScheduleClasses.normalize(classInput)
                    guard !query.isEmpty else { return }
                    if let cls = ScheduleClasses.validate(query, in: model.preferredGroup) {
                        prefs.selectedScheduleClass = cls
                    } else {
                        // same wording as the PDF viewer's class bar; the alert queues behind this one
                        Haptics.error()
                        scheduleUnavailable = L.f("noResults", query.uppercased())
                    }
                }
            }
        }
    }

    func retryButton(_ action: @escaping @MainActor () async -> Void) -> some View {
        Button { Haptics.light(); Task { await action() } } label: {
            Image(systemName: "arrow.clockwise").font(.footnote)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(L.s("a11y.retry"))
    }

    var skeletonRow: some View {
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
