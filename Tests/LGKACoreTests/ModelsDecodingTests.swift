import Foundation
import Testing
@testable import LGKACore

@Suite("API models decode the recorded responses")
struct ModelsDecodingTests {
    @Test func fullSyncDecodesEveryResource() throws {
        let sync = try Fixtures.sync("sync_full")
        let r = sync.resources
        #expect(r.substitutions?.status == .updated)
        #expect(r.schedules?.status == .updated)
        #expect(r.news?.status == .updated)
        #expect(r.events?.status == .updated)
        #expect(r.weather?.status == .updated)
        for hash in [r.substitutions?.hash, r.schedules?.hash, r.news?.hash, r.events?.hash, r.weather?.hash] {
            #expect(hash?.count == 16)
        }
    }

    @Test func substitutions() throws {
        let data = try #require(try Fixtures.sync("sync_full").resources.substitutions?.data)
        let today = try #require(data.today)
        #expect(today.source == "v_schueler_heute.pdf")
        #expect(today.pdf.sha256.count == 64)
        #expect(today.pdf.base64 != nil, "fixture was recorded with embed=pdf")
        #expect(today.meta.date.wholeMatch(of: #/\d{2}\.\d{2}\.\d{4}/#) != nil)
        #expect(!today.meta.weekday.isEmpty)
        #expect(today.canDisplay)
        #expect(!today.plan.entries.isEmpty)
        #expect(today.pages.count == today.pdf.pageCount)
        let entry = today.plan.entries[0]
        #expect(entry.type != nil)
        #expect(!entry.classes.isEmpty)
        #expect(entry.page == 0)
        // class filter matches the expanded class list
        let cls = entry.classes[0]
        #expect(today.plan.entries(forClass: cls.lowercased()).contains(entry))
        #expect(today.plan.entries(forClass: "zz").isEmpty)
        #expect(today.plan.footer?.calendarWeek != nil)
    }

    @Test func schedules() throws {
        let data = try #require(try Fixtures.sync("sync_full").resources.schedules?.data)
        #expect(data.items.count >= 3)
        let lower = try #require(data.items.first { $0.gradeLevel == "Klassen 5-10" })
        #expect(lower.available)
        #expect(lower.halbjahr == "1. Halbjahr" || lower.halbjahr == "2. Halbjahr")
        #expect(lower.classIndex["5a"] == 1, "class index is a real 1-based page")
        #expect(lower.pages.count == lower.pdf?.pageCount)
        #expect(lower.grades == Array(5...10))
        let j11 = try #require(data.items.first { $0.gradeLevel == "J11" })
        #expect(j11.classIndex["j11"] == 1)
        #expect(j11.covers("j11") && !j11.covers("7b"))
    }

    @Test func news() throws {
        let data = try #require(try Fixtures.sync("sync_full").resources.news?.data)
        #expect(data.articles.count >= 10)
        let first = data.articles[0]
        #expect(!first.title.isEmpty)
        #expect(first.url.hasPrefix("https://lessing-gymnasium-karlsruhe.de/"))
        #expect(first.publishedAt?.hasPrefix("20") == true)
        #expect(first.htmlContent != nil)
        // some article carries images with thumbnails (gallery)
        let withImages = try #require(data.articles.first { !$0.images.isEmpty })
        #expect(withImages.images.allSatisfy { $0.url.hasPrefix("https://") })
        // newest first
        let dates = data.articles.compactMap(\.publishedAt)
        #expect(dates == dates.sorted(by: >))
    }

    @Test func events() throws {
        let data = try #require(try Fixtures.sync("sync_full").resources.events?.data)
        #expect(data.horizonWeeks == 3)
        #expect(!data.events.isEmpty)
        for e in data.events {
            #expect(e.date.wholeMatch(of: #/\d{4}-\d{2}-\d{2}/#) != nil)
            if let t = e.time { #expect(t.wholeMatch(of: #/\d{2}:\d{2}/#) != nil) }
            #expect(!e.title.isEmpty)
        }
        #expect(data.events.map(\.date) == data.events.map(\.date).sorted())
    }

    @Test func weather() throws {
        let data = try #require(try Fixtures.sync("sync_full").resources.weather?.data)
        #expect(data.hourly.count == 72)
        #expect(data.daily.count == 3)
        #expect(data.timezone == "Europe/Berlin")
        #expect(data.current.provider == data.source)
        #expect(!data.attribution.isEmpty)
        if data.source == .openMeteo {
            #expect(!data.station.healthy)
            #expect(data.station.reason != nil)
            #expect(data.station.latest == nil)
        } else {
            #expect(data.station.healthy)
            #expect(data.station.latest != nil)
        }
        #expect(data.hourly[0].timeLabel == "00:00")
        #expect(data.station.units["temp"] == "°C")
    }

    @Test func partialAndUnavailableEnvelopes() throws {
        let partial = try Fixtures.sync("sync_partial")
        #expect(partial.resources.news?.status == .fresh)
        #expect(partial.resources.news?.data == nil)
        #expect(partial.resources.weather?.status == .updated)
        #expect(partial.resources.weather?.data != nil)

        let unavailable = try Fixtures.sync("sync_unavailable")
        #expect(unavailable.resources.substitutions?.status == .unavailable)
        #expect(unavailable.resources.substitutions?.hash == nil)
    }
}
