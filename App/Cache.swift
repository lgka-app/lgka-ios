import Foundation

/// Disk cache for raw fetched payloads (HTML/JSON/PDF bytes), keyed by URL.
/// Mirrors the Flutter app's persistent cache: schedule/news/weather/events
/// survive cold start; substitution stays fresh (short TTL). Parsing is fast
/// (verified core), so caching bytes keeps LGKACore untouched.
enum Cache {
    private static let dir: URL = {
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
        try? data.write(to: fileUrl(url))
    }
}

enum FetchMode {
    /// Fresh cache (within TTL) is good enough; otherwise network.
    case cacheFirst
    /// Any cache, no matter how old; otherwise network. (instant startup)
    case cacheAny
    /// Network; stale cache only as failure fallback.
    case refresh
}

extension SchoolAPI {
    /// TTLs mirroring the Flutter CacheService validity durations.
    enum TTL {
        static let substitution: TimeInterval = 60
        static let schedules: TimeInterval = 24 * 3600
        static let news: TimeInterval = 3600
        static let weather: TimeInterval = 3600
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
            let data = try await get(url, authenticated: authenticated)
            Cache.store(data, for: url)
            return data
        } catch {
            // stale fallback, like the Flutter services returning stale cache
            if let cached { return cached.data }
            throw error
        }
    }
}
