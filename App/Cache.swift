import Foundation
import os

/// Disk cache for raw fetched payloads (HTML/JSON/PDF bytes), keyed by URL.
/// Mirrors the Flutter app's persistent cache: schedule/news/weather/events
/// survive cold start; substitution stays fresh (short TTL). Parsing is fast
/// (verified core), so caching bytes keeps LGKACore untouched.
enum Cache {
    static let log = Logger(subsystem: "com.lgka", category: "cache")

    /// Entries untouched for longer than this are removed at startup.
    static let maxAge: TimeInterval = 14 * 24 * 3600

    static let dir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lgka-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    /// Stable FNV-1a hash (String.hashValue is seeded per-launch).
    static func key(_ url: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in url.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }

    static func fileUrl(_ url: String) -> URL {
        dir.appendingPathComponent(key(url))
    }

    static func load(_ url: String) -> (data: Data, age: TimeInterval)? {
        let file = fileUrl(url)
        guard let data = try? Data(contentsOf: file),
              let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
              let modified = attrs[.modificationDate] as? Date else { return nil }
        return (data, Date().timeIntervalSince(modified))
    }

    static func store(_ data: Data, for url: String) {
        do {
            try data.write(to: fileUrl(url), options: .atomic)
        } catch {
            log.error("store failed for \(url, privacy: .public): \(error)")
        }
    }

    static func remove(_ url: String) {
        try? FileManager.default.removeItem(at: fileUrl(url))
    }

    /// Deletes entries older than `maxAge` (dated event URLs and schedule
    /// PDFs would otherwise accumulate forever).
    static func evictStale(now: Date = Date()) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        var removed = 0
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            if now.timeIntervalSince(modified) > maxAge {
                try? fm.removeItem(at: file)
                removed += 1
            }
        }
        if removed > 0 { log.info("evicted \(removed) stale cache entries") }
    }
}

enum FetchMode: Sendable {
    /// Fresh cache (within TTL) is good enough; otherwise network.
    case cacheFirst
    /// Any cache, no matter how old; otherwise network. (instant startup)
    case cacheAny
    /// Network; stale cache only as failure fallback.
    case refresh
}

/// Serializes concurrent requests for the same URL: bootstrap, the
/// foreground refresh and the periodic loop may all ask for one resource at
/// once; only the first hits the network, the rest await its result.
actor Downloader {
    static let shared = Downloader()
    private var inFlight: [String: Task<Data, any Error>] = [:]

    func data(for url: String, authenticated: Bool) async throws -> Data {
        if let running = inFlight[url] { return try await running.value }
        let task = Task { try await SchoolAPI.fetch(url, authenticated: authenticated) }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        return try await task.value
    }
}

extension SchoolAPI {
    /// TTLs mirroring the Flutter CacheService validity durations.
    enum TTL {
        static let substitution: TimeInterval = 60
        static let schedules: TimeInterval = 24 * 3600
        static let news: TimeInterval = 3600
        static let weather: TimeInterval = 60 // CacheService parity (1 min)
        static let events: TimeInterval = 3600
    }

    static func cachedGet(_ url: String, authenticated: Bool = true,
                          ttl: TimeInterval, mode: FetchMode) async throws -> Data {
        let cached = Cache.load(url)
        switch mode {
        case .cacheAny:
            if let cached { return cached.data }
        case .cacheFirst:
            if let cached, cached.age < ttl { return cached.data }
        case .refresh:
            break
        }
        do {
            let data = try await Downloader.shared.data(for: url, authenticated: authenticated)
            Cache.store(data, for: url)
            return data
        } catch {
            // stale fallback, like the Flutter services returning stale cache
            if let cached {
                Cache.log.notice("using stale cache for \(url, privacy: .public): \(error)")
                return cached.data
            }
            throw error
        }
    }
}
