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
