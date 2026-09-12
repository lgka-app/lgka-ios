import Foundation
import Testing
@testable import LGKACore

/// Grade discovery must follow whatever the school uploads: a combined
/// "J11/12" PDF, split "J11" / "J12" PDFs, or a future J13 — never a constant.
struct ScheduleGradesTests {
    @Test func gradesFromTitles() {
        #expect(ScheduleGrades.fromTitle("Stundenpläne - 2026/2027 - 1.HJ - 5-10") == Array(5...10))
        #expect(ScheduleGrades.fromTitle("Stundenpläne - 2026/2027 - 1.HJ - J11") == [11])
        #expect(ScheduleGrades.fromTitle("Stundenpläne - 2026/2027 - 1.HJ - J12") == [12])
        #expect(ScheduleGrades.fromTitle("Stundenpläne - 2025/2026 - 1.HJ - J11/12") == [11, 12])
        #expect(ScheduleGrades.fromTitle("Stundenpläne 11-12") == [11, 12])
        #expect(ScheduleGrades.fromTitle("Stundenpläne - 2027/2028 - 1.HJ - J13") == [13])
        #expect(ScheduleGrades.fromTitle("Stundenpläne") == [])
    }

    @Test func classTokens() {
        #expect(ScheduleGrades.gradeOf("10b") == 10)
        #expect(ScheduleGrades.gradeOf("5a") == 5)
        #expect(ScheduleGrades.gradeOf("j11") == 11)
        #expect(ScheduleGrades.gradeOf("J13") == 13)
        #expect(ScheduleGrades.gradeOf("stundenplan") == nil)
        #expect(ScheduleGrades.gradeOf("7f") == nil)
    }
}

@Suite(.enabled(if: Goldens.root != nil, "lgka-app/verification checkout not found"))
struct JahrgangIndexTests {
    private func fixture(_ name: String) throws -> URL {
        try #require(Goldens.root).appendingPathComponent("fixtures/schedule/\(name)")
    }

    /// 2026/27: the site lists three PDFs; J11 and J12 must be discoverable, not "Unbekannt"-and-lost.
    @Test func splitJahrgangUploadsAreCovered() throws {
        let html = try String(contentsOf: fixture("stundenplan_page_2026-09-12.html"), encoding: .utf8)
        let schedules = try ScheduleHtmlParser.schedules(html)
        #expect(schedules.contains { $0.covers("10b") })
        #expect(schedules.contains { $0.covers("j11") })
        #expect(schedules.contains { $0.covers("j12") })
        #expect(schedules.first { $0.covers("j11") }?.grades == [11])
    }

    @Test func jahrgangIndexIsScannedFromPageHeaders() throws {
        #expect(try buildJahrgangIndex(url: fixture("stundenplan_hj1_11_09092026_10h42m_2026-09-12.pdf")) == ["j11": 2])
        #expect(try buildJahrgangIndex(url: fixture("stundenplan_hj1_12_09092026_10h42m_2026-09-12.pdf")) == ["j12": 2])
        // the 2025/26 combined PDF: j11 on its first page, j12 on its second (the old hardcoded values, now discovered)
        #expect(try buildJahrgangIndex(url: fixture("stundenplaene_j11j12_hj1_2025_2026_16092025_1300_2026-08-01.pdf")) == ["j11": 2, "j12": 3])
        // class PDFs carry no Jahrgang headers
        #expect(try buildJahrgangIndex(url: fixture("stundenplan_hj1_5-10_09092026_10h42m_2026-09-12.pdf")).isEmpty)
    }
}
