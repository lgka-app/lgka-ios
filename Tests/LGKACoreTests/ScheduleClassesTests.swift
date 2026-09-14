import Foundation
import Testing
@testable import LGKACore

/// A class is accepted in any casing and spacing, but only when a timetable of
/// the group lists it; the grade alone ("7f" in a 5-10 PDF) is not enough.
struct ScheduleClassesTests {
    private func item(_ title: String, _ index: [String: Int]) -> ScheduleItem {
        ScheduleItem(title: title, url: "", fullUrl: title, halbjahr: "1. Halbjahr",
                     gradeLevel: "Unbekannt", available: true, pdf: nil, classIndex: index, pages: [])
    }

    private var group: [ScheduleItem] {
        [item("Stundenpläne - 2026/2027 - 1.HJ - 5-10", ["7b": 12, "10b": 30]),
         item("Stundenpläne - 2026/2027 - 1.HJ - J11", ["j11": 1]),
         item("Stundenpläne - 2026/2027 - 1.HJ - J12", ["j12": 1])]
    }

    @Test func normalizesCaseAndWhitespace() {
        #expect(ScheduleClasses.normalize(" 10 B\n") == "10b")
        #expect(ScheduleClasses.normalize("J11") == "j11")
        #expect(ScheduleClasses.normalize("") == "")
    }

    @Test func acceptsAnyCasingAndSpacing() {
        for input in ["10B", "10b", " 10b ", "10 b", "\t10B"] {
            #expect(ScheduleClasses.validate(input, in: group) == "10b")
        }
        #expect(ScheduleClasses.validate("J11", in: group) == "j11")
        #expect(ScheduleClasses.validate("j11", in: group) == "j11")
    }

    @Test func rejectsClassesNoIndexLists() {
        #expect(ScheduleClasses.validate("7f", in: group) == nil)
        #expect(ScheduleClasses.validate("7c", in: group) == nil, "grade 7 is covered, the class is not listed")
        #expect(ScheduleClasses.validate("j13", in: group) == nil)
        #expect(ScheduleClasses.validate("stundenplan", in: group) == nil)
        #expect(ScheduleClasses.validate("", in: group) == nil)
        #expect(ScheduleClasses.validate("7b", in: []) == nil)
    }

    @Test func indexIsTheUnionAcrossThePdfsOfTheGroup() {
        #expect(ScheduleClasses.known(in: group) == ["7b", "10b", "j11", "j12"])
        #expect(ScheduleClasses.validate("J12", in: group) == "j12")
        #expect(ScheduleClasses.validate("7B", in: group) == "7b")
    }

    @Test func worksWithTheFixtureSchedules() throws {
        let items = try #require(try Fixtures.sync("sync_full").resources.schedules?.data?.items)
        let group = ScheduleItem.preferredGroup(items)
        let known = ScheduleClasses.known(in: group)
        #expect(!known.isEmpty)
        for cls in known {
            #expect(ScheduleClasses.validate(" " + cls.uppercased() + " ", in: group) == cls)
        }
    }
}
