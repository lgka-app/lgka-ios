import Foundation
import os
import LGKACore

/// Home hub state — mirrors home_screen.dart: weather, substitution plans,
/// schedules, upcoming events, news list. Observable and main-actor
/// isolated; injected through the environment (no singleton).
@Observable
@MainActor
final class HomeModel {
    private static let log = Logger(subsystem: "com.lgka", category: "home")

    var newsList: [NewsParser.Metadata]?
    var newsFailed = false
    var today: SchoolAPI.SubPlan?
    var tomorrow: SchoolAPI.SubPlan?
    var subError = false
    var subLoading = true

    var weather: SchoolAPI.WeatherData?
    var weatherError = false

    var schedules: [SchoolAPI.Schedule] = []
    var scheduleError = false
    var scheduleLoading = true

    var events: [SchoolAPI.Event] = []
    var eventsError = false
    var eventsLoading = true

    private var bootstrapped = false
    private var bootstrapFinished = false
    private var lastForegroundRefresh = Date.distantPast

    /// Startup preload, mirroring main.dart's _preloadData:
    /// phase 1 shows any cached data instantly, phase 2 refreshes per TTL,
    /// then news article contents are prefetched into the cache.
    func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true
        Cache.evictStale()
        await loadAll(mode: .cacheAny)
        await loadAll(mode: .cacheFirst)
        bootstrapFinished = true
        lastForegroundRefresh = Date()
        await prefetchArticles()
    }

    /// Scene became active: refresh substitution + weather unless bootstrap
    /// is still running or we refreshed seconds ago (launch fires both).
    func refreshOnForeground() async {
        guard bootstrapFinished,
              Date().timeIntervalSince(lastForegroundRefresh) > 10 else { return }
        lastForegroundRefresh = Date()
        async let a: () = loadSubstitution(mode: .refresh)
        async let b: () = loadWeather(mode: .refresh)
        _ = await (a, b)
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
            Self.log.error("news: \(error)")
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
            Self.log.error("substitution: \(error)")
            if today == nil { subError = true }
        }
        subLoading = false
    }

    func loadWeather(mode: FetchMode = .cacheFirst) async {
        do {
            weather = try await SchoolAPI.weather(mode: mode)
            weatherError = false
        } catch {
            Self.log.error("weather: \(error)")
            if weather == nil { weatherError = true }
        }
    }

    func loadSchedules(mode: FetchMode = .cacheFirst) async {
        scheduleLoading = schedules.isEmpty
        do {
            schedules = try await SchoolAPI.schedules(mode: mode)
            scheduleError = false
        } catch {
            Self.log.error("schedules: \(error)")
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
            Self.log.error("events: \(error)")
            if events.isEmpty { eventsError = true }
        }
        eventsLoading = false
    }
}
