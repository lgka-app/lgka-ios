import Foundation
import Testing
@testable import LGKACore

@Suite("Hourly window")
struct WeatherWindowTests {
    @Test func windowIs24HoursFromTheCurrentHour() throws {
        let weather = try #require(try Fixtures.sync("sync_full").resources.weather?.data)
        let firstDay = String(weather.hourly[0].dt.prefix(10))
        let window = weather.hourly(from: "\(firstDay)T13:37")
        #expect(window.count == 24)
        #expect(window.first?.dt == "\(firstDay)T13:00")
        #expect(window.last?.dt.hasSuffix("T12:00") == true)
        #expect(window.last?.dt.prefix(10) != Substring(firstDay))
    }

    @Test func windowAtTheHorizonIsShorter() throws {
        let weather = try #require(try Fixtures.sync("sync_full").resources.weather?.data)
        let lastDay = String(weather.hourly[71].dt.prefix(10))
        #expect(weather.hourly(from: "\(lastDay)T20:05").count == 4) // 20,21,22,23
        #expect(weather.hourly(from: "2030-01-01T00:00").isEmpty)
    }

    @Test func minuteKeyIsMonotonicAndValidates() {
        #expect(WeatherWindow.minuteKey("2026-09-12T13:00")! + 60 == WeatherWindow.minuteKey("2026-09-12T14:00")!)
        #expect(WeatherWindow.minuteKey("2026-09-12T23:00")! + 60 == WeatherWindow.minuteKey("2026-09-13T00:00")!)
        #expect(WeatherWindow.minuteKey("2026-02-28T23:00")! + 60 == WeatherWindow.minuteKey("2026-03-01T00:00")!)
        #expect(WeatherWindow.minuteKey("garbage") == nil)
        #expect(WeatherWindow.minuteKey("2026-13-01T00:00") == nil)
    }

    @Test func localNowFormatsBerlinWallClock() {
        let date = Date(timeIntervalSince1970: 1_789_000_000) // 2026-09-... UTC
        let s = WeatherWindow.localNow(date, timeZone: TimeZone(identifier: "Europe/Berlin")!)
        #expect(s.wholeMatch(of: #/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/#) != nil)
        let utc = WeatherWindow.localNow(date, timeZone: TimeZone(identifier: "UTC")!)
        #expect(s != utc) // Berlin is UTC+1/+2
    }
}

@Suite("Schedule class → page")
struct ScheduleClassPageTests {
    @Test func classIndexIsOneBasedAndViewerIndexIsZeroBased() throws {
        let data = try #require(try Fixtures.sync("sync_full").resources.schedules?.data)
        let lower = try #require(data.items.first { $0.gradeLevel == "Klassen 5-10" })
        #expect(lower.classIndex["5a"] == 1)
        #expect(lower.pageIndex(forClass: "5a") == 0)
        #expect(lower.pageIndex(forClass: "5A") == 0)
        #expect(lower.pageIndex(forClass: "j11") == nil)
        // every indexed page exists in the PDF
        for (_, page) in lower.classIndex {
            #expect(page >= 1 && page <= lower.pdf!.pageCount)
        }
    }

    @Test func coverageAndGradeFallback() {
        var item = ScheduleItem(title: "Stundenpläne - 2026/2027 - 1.HJ - J12", url: "", fullUrl: "u", halbjahr: "1. Halbjahr",
                                gradeLevel: "J12", available: true, pdf: nil, classIndex: ["j12": 1], pages: [])
        #expect(item.grades == [12])
        #expect(item.covers("J12") && !item.covers("j11") && !item.covers("9c"))
        item.title = "Stundenpläne" // no grade in the title → API label decides
        #expect(item.grades == [12])
        item.gradeLevel = "J11/J12"
        #expect(item.grades == [11, 12])
        item.gradeLevel = "Klassen 5-10"
        #expect(item.covers("10e") && !item.covers("j11"))
    }

    @Test func classIndexWinsOverGradeDiscovery() {
        // the index was built from the PDF's text: it knows better than the title
        var item = ScheduleItem(title: "Stundenpläne - 2026/2027 - 1.HJ - 5-10", url: "", fullUrl: "u", halbjahr: "1. Halbjahr",
                                gradeLevel: "Klassen 5-10", available: true, pdf: nil, classIndex: ["5a": 1, "j11": 20], pages: [])
        #expect(item.covers("J11"), "listed in the index although the title says 5-10")
        #expect(item.covers("7c"), "grade fallback still applies")
        item.classIndex = [:]
        #expect(!item.covers("j11") && item.covers("7c"))
    }

    @Test func preferredGroupOffersPublishedTimetablesOnly() {
        func item(_ half: String, _ grade: String, published: Bool) -> ScheduleItem {
            ScheduleItem(title: "Stundenpläne - 2026/2027 - \(half == "1. Halbjahr" ? "1" : "2").HJ - \(grade)", url: "", fullUrl: "\(half)/\(grade)",
                         halbjahr: half, gradeLevel: grade == "5-10" ? "Klassen 5-10" : grade, available: published,
                         pdf: published ? PdfRef(url: "/v1/files/x.pdf", sha256: String(repeating: "a", count: 64), bytes: 1, pageCount: 1, base64: nil) : nil,
                         classIndex: [:], pages: [])
        }
        let first = [item("1. Halbjahr", "5-10", published: true), item("1. Halbjahr", "J11", published: true)]
        let secondUnpublished = [item("2. Halbjahr", "5-10", published: false), item("2. Halbjahr", "J11", published: false)]
        // 2. Halbjahr listed but not uploaded yet → keep offering the published 1. Halbjahr
        #expect(ScheduleItem.preferredGroup(first + secondUnpublished).map(\.fullUrl) == first.map(\.fullUrl))
        // once one 2. Halbjahr PDF is published, only published ones are offered
        let partlyPublished = [item("2. Halbjahr", "5-10", published: true), item("2. Halbjahr", "J11", published: false)]
        #expect(ScheduleItem.preferredGroup(first + partlyPublished).map(\.fullUrl) == ["2. Halbjahr/5-10"])
        // nothing published anywhere → the preferred semester as-is, so the UI can say why
        #expect(ScheduleItem.preferredGroup(secondUnpublished).count == 2)
        #expect(ScheduleItem.preferredGroup([]).isEmpty)
    }
}
