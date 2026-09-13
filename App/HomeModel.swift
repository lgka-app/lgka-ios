import Foundation
import os
import LGKACore

/// Home hub state. Everything the screens show comes from one `SyncState`:
/// loaded from disk first (instant, offline), then reconciled with a single
/// `/v1/sync` call carrying the hashes we hold. Observable, main-actor.
@Observable
@MainActor
final class HomeModel {
    private static let log = Logger(subsystem: "com.lgka", category: "home")
    private let client: APIClient
    private let store: SyncStore

    private(set) var state = SyncState()
    private(set) var isSyncing = false
    /// The last sync could not reach the API (offline, 5xx, decoding).
    private(set) var syncFailed = false
    /// Resources the API reported as never fetched.
    private(set) var unavailable: Set<Resource> = []
    /// Set when the API rejected the stored credentials (school rotated the password).
    var unauthorized = false

    private var bootstrapped = false
    private var bootstrapFinished = false
    private var lastForegroundRefresh = Date.distantPast
    /// Bumped by `clear()`: a sync still in flight at sign-out must not write
    /// its answer back into the wiped store or sign the next user out.
    private var generation = 0

    init(client: APIClient = SchoolAPI.client, store: SyncStore = SchoolAPI.store) {
        self.client = client
        self.store = store
    }

    // ── Derived views of the state ──────────────────────────────────────────

    var today: DayPlan? { state.substitutions?.data.today }
    var tomorrow: DayPlan? { state.substitutions?.data.tomorrow }
    var subLoading: Bool { loading(.substitutions) }
    var subError: Bool { failed(.substitutions) }

    var weather: WeatherData? { state.weather?.data }
    var weatherError: Bool { failed(.weather) }
    /// The next 24 hours from the current Berlin hour (the API ships 72).
    var hourly: [HourlyForecast] { weather?.hourly(from: WeatherWindow.localNow()) ?? [] }

    var schedules: [ScheduleItem] { state.schedules?.data.items ?? [] }
    var scheduleLoading: Bool { loading(.schedules) }
    var scheduleError: Bool { failed(.schedules) }

    var events: [SchoolEvent] { state.events?.data.events ?? [] }
    var eventsLoading: Bool { loading(.events) }
    var eventsError: Bool { failed(.events) }

    var newsList: [NewsArticle]? { state.news?.data.articles }
    var newsFailed: Bool { failed(.news) }

    /// Published timetables of the newest semester (2. Halbjahr over 1. Halbjahr).
    var preferredGroup: [ScheduleItem] { ScheduleItem.preferredGroup(schedules) }

    private func has(_ r: Resource) -> Bool { state.hashes[r] != nil }
    /// Nothing on disk yet and no verdict from the API yet → skeleton.
    private func loading(_ r: Resource) -> Bool { !has(r) && !syncFailed && !unavailable.contains(r) }
    /// Nothing on disk and the API could not help → error state with retry.
    private func failed(_ r: Resource) -> Bool { !has(r) && (syncFailed || unavailable.contains(r)) }

    // ── Lifecycle ───────────────────────────────────────────────────────────

    /// Startup: render the last known state immediately, then one sync.
    func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true
        state = store.loadState()
        await sync()
        bootstrapFinished = true
        lastForegroundRefresh = Date()
    }

    /// Scene became active: one sync unless bootstrap is still running or we
    /// synced seconds ago (launch fires both).
    func refreshOnForeground() async {
        guard bootstrapFinished, Date().timeIntervalSince(lastForegroundRefresh) > 10 else { return }
        lastForegroundRefresh = Date()
        await sync()
    }

    /// The one network call. `only` narrows it to a retry of specific resources.
    func sync(only: [Resource]? = nil) async {
        if isSyncing { return }
        isSyncing = true
        let started = generation
        defer { if generation == started { isSyncing = false } }
        do {
            let response = try await client.sync(hashes: state.hashes, only: only, embedPdf: true)
            guard generation == started else { return }
            var next = state
            let outcome = store.apply(response, to: &next)
            state = next
            syncFailed = false
            unavailable.subtract(only ?? Resource.allCases)
            unavailable.formUnion(outcome.unavailable)
            if !outcome.updated.isEmpty {
                Self.log.info("sync: updated \(outcome.updated.map(\.rawValue).sorted().joined(separator: ","), privacy: .public)")
            }
        } catch APIError.unauthorized {
            // A 401 on a data route is confirmed with one /v1/auth/check before
            // anyone is signed out; the on-disk snapshot is kept either way.
            let verdict = await client.verifyStoredCredentials()
            guard generation == started else { return }
            switch verdict {
            case .rotated:
                Self.log.error("sync: credentials rejected, confirmed by /v1/auth/check")
                unauthorized = true
                // the next sign-in shows this snapshot again and syncs straight away
                bootstrapped = false
            case .valid, .undetermined:
                Self.log.error("sync: 401 not confirmed by /v1/auth/check, treating as transient")
                syncFailed = true
            }
        } catch {
            guard generation == started else { return }
            Self.log.error("sync: \(error)")
            syncFailed = true
        }
    }

    /// Wipes the local snapshot. Only for an explicit sign-out in Settings; a
    /// rotated school password keeps the data (public school content — the
    /// user gets it back right after re-login).
    func clear() {
        generation += 1
        isSyncing = false
        // the home screen of the next sign-in bootstraps (and syncs) again
        bootstrapped = false
        bootstrapFinished = false
        store.removeAll()
        state = SyncState()
        unavailable = []
        syncFailed = false
        unauthorized = false
    }

    // ── Files ───────────────────────────────────────────────────────────────

    /// Local file for a mirrored PDF: written by the sync (embedded), or fetched
    /// once from the API when an older snapshot lacks the file.
    func pdfURL(for ref: PdfRef) async throws -> URL {
        if store.hasPdf(sha256: ref.sha256) { return store.pdfURL(sha256: ref.sha256) }
        let bytes = try await client.pdf(sha256: ref.sha256)
        try store.storePdf(sha256: ref.sha256, bytes: bytes)
        return store.pdfURL(sha256: ref.sha256)
    }
}
