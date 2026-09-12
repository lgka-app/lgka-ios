import Foundation
import Testing
@testable import LGKACore

/// The data layer must never trap on server data: malformed input throws.
struct RobustnessTests {
    @Test func weatherRejectsNonJSON() {
        #expect(throws: LGKAError.self) {
            try WeatherParser.parse("not json", referenceNow: "2026-09-12T12:00")
        }
    }

    @Test func weatherRejectsNullRequiredField() {
        let json = """
        {"current":{"time":"2026-09-12T12:00","temperature_2m":null,"apparent_temperature":1,
          "relative_humidity_2m":1,"wind_speed_10m":1,"wind_direction_10m":1,"pressure_msl":1,
          "weather_code":1},
         "hourly":{"time":[],"temperature_2m":[],"relative_humidity_2m":[],"weather_code":[],
          "precipitation_probability":[],"wind_speed_10m":[],"wind_direction_10m":[],"is_day":[]},
         "daily":{"time":[],"weather_code":[],"temperature_2m_max":[],"temperature_2m_min":[],
          "precipitation_probability_max":[],"uv_index_max":[],"wind_speed_10m_max":[],
          "sunrise":[],"sunset":[]}}
        """
        #expect(throws: LGKAError.missingField("current.temperature_2m")) {
            try WeatherParser.parse(json, referenceNow: "2026-09-12T12:00")
        }
    }

    @Test func weatherToleratesNullsInArrays() throws {
        let json = """
        {"current":{"time":"2026-09-12T12:00","temperature_2m":20,"apparent_temperature":19,
          "relative_humidity_2m":50,"wind_speed_10m":5,"wind_direction_10m":90,"pressure_msl":1013.4,
          "weather_code":2,"is_day":1,"uv_index":null,"visibility":null},
         "hourly":{"time":["2026-09-12T12:00","2026-09-12T13:00"],"temperature_2m":[20,null],
          "relative_humidity_2m":[50,null],"weather_code":[2,null],
          "precipitation_probability":[10,null],"wind_speed_10m":[5,null],
          "wind_direction_10m":[90,null],"is_day":[1,null]},
         "daily":{"time":["2026-09-12"],"weather_code":[2],"temperature_2m_max":[22],
          "temperature_2m_min":[12],"precipitation_probability_max":[null],"uv_index_max":[3],
          "wind_speed_10m_max":[8],"sunrise":["2026-09-12T06:58"],"sunset":["2026-09-12T19:41"]}}
        """
        let r = try WeatherParser.parse(json, referenceNow: "2026-09-12T12:00")
        let hourly = try #require(r["hourly"] as? [[String: Any]])
        #expect(hourly.count == 2)
        #expect(hourly[1]["temp"] as? Double == 0)
        let current = try #require(r["current"] as? [String: Any])
        #expect(current["pressure"] as? Int == 1013)
        #expect(current["uvi"] as? Double == 0)
    }

    @Test func minuteKeyIsMonotonic() throws {
        #expect(try WeatherParser.minuteKey("2026-09-12T12:00") + 60
            == WeatherParser.minuteKey("2026-09-12T13:00"))
        #expect(try WeatherParser.minuteKey("2026-12-31T23:59") + 1
            == WeatherParser.minuteKey("2027-01-01T00:00"))
        #expect(throws: LGKAError.self) { try WeatherParser.minuteKey("garbage") }
    }

    @Test func extractorMarksShortPagesEmpty() throws {
        let plan = try Extractor.extract(lines: [Line(top: 0, words: [Word(text: "Hi", left: 0, right: 5)])])
        #expect(plan["isEmpty"] as? Bool == true)
    }

    @Test func extractorThrowsOnUnexpectedHeader() {
        func line(_ y: Double, _ texts: [String]) -> Line {
            var x = 0.0
            let words = texts.map { t -> Word in
                defer { x += 40 }
                return Word(text: t, left: x, right: x + 20)
            }
            return Line(top: y, words: words)
        }
        let lines = [
            line(10, ["Lessing-Gymnasium", "Karlsruhe"]),
            line(20, ["Klassen", "12.9.", "/", "Freitag", "Vertretungen"]),
            line(30, ["Art", "Stunde", "Klasse"]), // 3 columns instead of 10
            line(40, ["Entfall", "1", "5a", "---", "M", "R101", "M", "XY", "R101", "x"]),
            line(50, ["12.9.2026", "(37)", "SJ", "2026-27", "padding", "padding", "padding"]),
        ]
        #expect(throws: LGKAError.unexpectedTableHeader(found: 3, expected: 10)) {
            try Extractor.extract(lines: lines)
        }
    }

    @Test func scheduleParserThrowsTyped() {
        #expect(throws: LGKAError.scheduleModuleMissing) {
            try ScheduleHtmlParser.parse("<html><body>nothing</body></html>")
        }
        #expect(throws: LGKAError.noSchedulesFound) {
            try ScheduleHtmlParser.parse("<div id=\"mod-custom213\"><a href=\"/x.pdf\">x</a></div>")
        }
    }

    @Test func eventsParsePastAndFuture() {
        let html = """
        <li class="ev_td_li"><a href="/cm3/index.php/termine/icalrepeat.detail/2026/09/10/1/-/x" title="Alt">09:00 Uhr</a></li>
        <li class="ev_td_li"><a href="/cm3/index.php/termine/icalrepeat.detail/2026/09/14/2/-/y" title="Kurzkonferenz &amp; Info">07:30 Uhr</a></li>
        """
        let events = EventsParser.upcoming(weekHtmls: [html, html], today: "2026-09-12")
        #expect(events.count == 1)
        #expect(events.first?.title == "Kurzkonferenz & Info")
        #expect(events.first?.time == "07:30")
    }

    @Test func newsHandlesEmptyDocuments() throws {
        #expect(try NewsParser.parseListPage("<html></html>").isEmpty)
        let article = try NewsParser.parseArticle("<html></html>")
        #expect(article.content == nil)
    }

    @Test func pdfHelpersThrowOnMissingFile() {
        let missing = URL(fileURLWithPath: "/nonexistent/file.pdf")
        #expect(throws: LGKAError.pdfUnreadable) { try extractLines(from: missing) }
        #expect(throws: LGKAError.pdfUnreadable) { try buildClassIndex(url: missing) }
        #expect(throws: LGKAError.pdfUnreadable) { try pageTexts(url: missing) }
    }
}
