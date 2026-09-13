import Foundation

// The `/v1/sync` protocol and the on-disk store it feeds.
//
//   GET /v1/sync?substitutions=<hash>&…&embed=pdf
//   → per resource: fresh (keep local) | updated (hash + data) | unavailable
//
// `SyncStore` keeps one JSON snapshot per resource in Application Support and
// the mirrored PDFs as files next to them, so every screen renders offline
// from the last known state and a launch costs one request.

// MARK: - Envelope

public enum SyncStatus: String, Codable, Sendable {
    case fresh, updated, unavailable
}

public struct SyncEntry<T: Codable & Sendable>: Codable, Sendable {
    public var status: SyncStatus
    public var hash: String?
    public var updatedAt: String?
    public var sourceUpdatedAt: String?
    public var data: T?

    public init(status: SyncStatus, hash: String? = nil, updatedAt: String? = nil, sourceUpdatedAt: String? = nil, data: T? = nil) {
        self.status = status
        self.hash = hash
        self.updatedAt = updatedAt
        self.sourceUpdatedAt = sourceUpdatedAt
        self.data = data
    }
}

public struct SyncResponse: Codable, Sendable {
    public var generatedAt: String
    public var resources: Resources

    public struct Resources: Codable, Sendable {
        public var substitutions: SyncEntry<SubstitutionsData>?
        public var schedules: SyncEntry<SchedulesData>?
        public var news: SyncEntry<NewsData>?
        public var events: SyncEntry<EventsData>?
        public var weather: SyncEntry<WeatherData>?
    }
}

/// One persisted resource: what the API sent plus the hash it is known by.
public struct Snapshot<T: Codable & Sendable>: Codable, Sendable {
    public var hash: String
    public var updatedAt: String
    public var sourceUpdatedAt: String?
    /// When this device stored it.
    public var storedAt: Date
    public var data: T

    public init(hash: String, updatedAt: String, sourceUpdatedAt: String? = nil, storedAt: Date = Date(), data: T) {
        self.hash = hash
        self.updatedAt = updatedAt
        self.sourceUpdatedAt = sourceUpdatedAt
        self.storedAt = storedAt
        self.data = data
    }
}

/// Everything the app knows, as loaded from disk / after a sync.
public struct SyncState: Sendable {
    public var substitutions: Snapshot<SubstitutionsData>?
    public var schedules: Snapshot<SchedulesData>?
    public var news: Snapshot<NewsData>?
    public var events: Snapshot<EventsData>?
    public var weather: Snapshot<WeatherData>?

    public init() {}

    /// Query parameters for `/v1/sync`: the hash of every resource we hold.
    public var hashes: [Resource: String] {
        var out: [Resource: String] = [:]
        if let h = substitutions?.hash { out[.substitutions] = h }
        if let h = schedules?.hash { out[.schedules] = h }
        if let h = news?.hash { out[.news] = h }
        if let h = events?.hash { out[.events] = h }
        if let h = weather?.hash { out[.weather] = h }
        return out
    }
}

/// Outcome of applying one sync response.
public struct SyncOutcome: Sendable, Equatable {
    public var updated: Set<Resource> = []
    public var fresh: Set<Resource> = []
    public var unavailable: Set<Resource> = []
    public init() {}
}

// MARK: - Store

/// Disk persistence for `SyncState`. Not an actor: callers serialise access
/// (the app uses it from one main-actor model; tests from one task).
public final class SyncStore: @unchecked Sendable {
    public let directory: URL
    public let filesDirectory: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Default location: Application Support/lgka (excluded from backup — it is a cache).
    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("lgka", isDirectory: true)
    }

    public init(directory: URL = SyncStore.defaultDirectory()) {
        self.directory = directory
        self.filesDirectory = directory.appendingPathComponent("files", isDirectory: true)
        createDirectories()
    }

    /// The exclusion lives on the directory itself, so it has to be set again
    /// whenever the directory is recreated.
    private func createDirectories() {
        try? FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var dir = directory
        try? dir.setResourceValues(values)
    }

    // ---- files ----

    public func pdfURL(sha256: String) -> URL {
        filesDirectory.appendingPathComponent("\(sha256).pdf")
    }

    public func hasPdf(sha256: String) -> Bool {
        FileManager.default.fileExists(atPath: pdfURL(sha256: sha256).path)
    }

    /// Writes `bytes` for `sha256` unless the file already exists.
    public func storePdf(sha256: String, bytes: Data) throws {
        let url = pdfURL(sha256: sha256)
        if FileManager.default.fileExists(atPath: url.path) { return }
        try bytes.write(to: url, options: .atomic)
    }

    // ---- snapshots ----

    private func url(_ resource: Resource) -> URL {
        directory.appendingPathComponent("\(resource.rawValue).json")
    }

    public func load<T: Codable & Sendable>(_ resource: Resource, as type: T.Type) -> Snapshot<T>? {
        guard let data = try? Data(contentsOf: url(resource)) else { return nil }
        return try? decoder.decode(Snapshot<T>.self, from: data)
    }

    public func save<T: Codable & Sendable>(_ snapshot: Snapshot<T>, for resource: Resource) throws {
        try encoder.encode(snapshot).write(to: url(resource), options: .atomic)
    }

    public func removeAll() {
        try? FileManager.default.removeItem(at: directory)
        createDirectories()
    }

    public func loadState() -> SyncState {
        var s = SyncState()
        s.substitutions = load(.substitutions, as: SubstitutionsData.self)
        s.schedules = load(.schedules, as: SchedulesData.self)
        s.news = load(.news, as: NewsData.self)
        s.events = load(.events, as: EventsData.self)
        s.weather = load(.weather, as: WeatherData.self)
        return s
    }

    // ---- merge ----

    /// Applies a sync response to `state`: `updated` entries are persisted
    /// (embedded PDFs written to disk and stripped), `fresh`/`unavailable`
    /// keep what we have. Returns what changed.
    @discardableResult
    public func apply(_ response: SyncResponse, to state: inout SyncState, now: Date = Date()) -> SyncOutcome {
        var outcome = SyncOutcome()
        let r = response.resources

        if let e = r.substitutions {
            merge(.substitutions, e, into: &state.substitutions, outcome: &outcome, now: now) { data in
                var d = data
                if var today = d.today { self.detachPdf(&today.pdf); d.today = today }
                if var tomorrow = d.tomorrow { self.detachPdf(&tomorrow.pdf); d.tomorrow = tomorrow }
                return d
            }
        }
        if let e = r.schedules {
            merge(.schedules, e, into: &state.schedules, outcome: &outcome, now: now) { data in
                var d = data
                d.items = d.items.map { item in
                    var i = item
                    if var pdf = i.pdf { self.detachPdf(&pdf); i.pdf = pdf }
                    return i
                }
                return d
            }
        }
        if let e = r.news { merge(.news, e, into: &state.news, outcome: &outcome, now: now) { $0 } }
        if let e = r.events { merge(.events, e, into: &state.events, outcome: &outcome, now: now) { $0 } }
        if let e = r.weather { merge(.weather, e, into: &state.weather, outcome: &outcome, now: now) { $0 } }
        return outcome
    }

    private func merge<T: Codable & Sendable>(
        _ resource: Resource,
        _ entry: SyncEntry<T>,
        into slot: inout Snapshot<T>?,
        outcome: inout SyncOutcome,
        now: Date,
        prepare: (T) -> T
    ) {
        switch entry.status {
        case .fresh:
            outcome.fresh.insert(resource)
            // the server confirmed our hash; refresh the bookkeeping timestamp only
            if var s = slot, let h = entry.hash, h == s.hash {
                s.storedAt = now
                slot = s
                try? save(s, for: resource)
            }
        case .unavailable:
            outcome.unavailable.insert(resource)
        case .updated:
            guard let data = entry.data, let hash = entry.hash else {
                outcome.unavailable.insert(resource)
                return
            }
            let snapshot = Snapshot(hash: hash, updatedAt: entry.updatedAt ?? "", sourceUpdatedAt: entry.sourceUpdatedAt, storedAt: now, data: prepare(data))
            slot = snapshot
            try? save(snapshot, for: resource)
            outcome.updated.insert(resource)
        }
    }

    /// Writes an embedded PDF to disk and drops the base64 from the model.
    private func detachPdf(_ ref: inout PdfRef) {
        if let b64 = ref.base64, let bytes = Data(base64Encoded: b64) {
            try? storePdf(sha256: ref.sha256, bytes: bytes)
        }
        ref.base64 = nil
    }
}
