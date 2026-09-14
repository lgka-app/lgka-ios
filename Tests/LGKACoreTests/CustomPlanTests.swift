import Foundation
import Testing
import PDFKit
@testable import LGKACore
@testable import LGKAPlanKit

/// The custom J11 timetable end to end on recorded input: the words of the real J11 Stufenplan
/// (2026/27, 1. Halbjahr; teacher codes replaced) and the text recognised on a photo of a
/// Kurswahlprotokoll (name replaced, SchID and birth date removed).
@Suite("Custom plan")
struct CustomPlanTests {
    static func stufenplan() throws -> Stufenplan {
        try StufenplanParser.parse(JSONDecoder().decode([TextBox].self, from: Fixtures.data("stufenplan_j11_words")))
    }

    static func kurswahl() throws -> Kurswahl {
        try KurswahlParser.parse(JSONDecoder().decode([TextBox].self, from: Fixtures.data("kurswahl_ocr")))
    }

    // MARK: Stufenplan

    @Test func stufenplanHeaderAndSlots() throws {
        let plan = try Self.stufenplan()
        #expect(plan.stufe == "J11")
        #expect(plan.schuljahr == "2026-2027")
        #expect(plan.stand == "7.9.2026 14:39")
        #expect(plan.slots.count == 129)
    }

    @Test func stufenplanDoubleSingleAndRooms() throws {
        let plan = try Self.stufenplan()
        func slot(_ code: String, day: Int, start: Int) -> Stufenplan.Slot? {
            plan.slots.first { $0.code == code && $0.day == day && $0.start == start }
        }
        // double period, leading Untis dot removed
        #expect(slot("M3", day: 0, start: 1)?.end == 2)
        #expect(slot("M3", day: 0, start: 1)?.room == "301")
        // single periods stacked in the 7-9 block
        #expect(slot("bio2", day: 1, start: 9)?.end == 9)
        #expect(slot("bio2", day: 1, start: 9)?.room == "NWT1")
        // a double period across 8 and 9
        #expect(slot("bio3", day: 2, start: 8)?.end == 9)
        // a cell without a room (Helmholtz cooperation course)
        #expect(slot("Esp", day: 0, start: 5)?.room == nil)
        // basis sport, three parallel courses in one slot
        #expect(["s1", "s2", "s3"].map { slot($0, day: 0, start: 10)?.room } == ["WB2", "FrEb", "Less"])
    }

    // MARK: Kurswahlprotokoll

    @Test func cellValues() {
        #expect(KurswahlParser.parseCell("5(3)").hours == 5)
        #expect(KurswahlParser.parseCell("5(3)").parallel == 3)
        #expect(KurswahlParser.parseCell("2(3).Р").parallel == 3) // Cyrillic P from recognition
        #expect(KurswahlParser.parseCell("2 (3) .p").hours == 2)
        #expect(KurswahlParser.parseCell("2.s").hours == 2)
        #expect(KurswahlParser.parseCell("2.s").parallel == nil)
        #expect(KurswahlParser.parseCell("-").taken == false)
        #expect(KurswahlParser.parseCell("-").unreadable == false)
        #expect(KurswahlParser.parseCell("..E").unreadable == false)
        #expect(KurswahlParser.parseCell("5(8").hours == 5)
        #expect(KurswahlParser.parseCell("a7x").unreadable)
    }

    @Test func kurswahlFromPhoto() throws {
        let k = try Self.kurswahl()
        #expect(k.name == "Max Muster")
        #expect(k.abiturjahr == 2028)
        #expect(k.konfession == .katholisch)
        #expect(k.sums.first == 34)
        #expect(k.grade(inSchuljahr: "2026-2027") == 11)
        #expect(k.grade(inSchuljahr: "2027-2028") == 12)
        func hj1(_ subject: String) -> Kurswahl.Cell? { k.rows.first { $0.subject == subject }?.halves.first }
        #expect(hj1("D")?.hours == 5 && hj1("D")?.parallel == 3)
        #expect(hj1("Gk")?.hours == 2 && hj1("Gk")?.parallel == 3)
        #expect(hj1("Sport")?.parallel == 1)
        #expect(hj1("Psy")?.parallel == 1)
        #expect(hj1("Geo")?.taken == false)
        #expect(k.rows.first { $0.subject == "Geo" }?.halves[1].hours == 2)
    }

    // MARK: Plan

    @Test func planFromPhotoMatchesTheHandMadeOne() throws {
        let plan = CustomPlanBuilder.build(kurswahl: try Self.kurswahl(), plan: try Self.stufenplan(), halbjahr: "1. Halbjahr")
        #expect(plan.checks.issues.map(\.message) == [])
        #expect(plan.checks.totalHours == 34)
        #expect(Set(plan.courses.map(\.id)) == ["D3", "E3", "esp", "bk2", "g2", "gk3", "kR1", "m1", "ch1", "S1", "psy1"])
        #expect(plan.courses.first { $0.id == "S1" }?.title == "Sport (LF, S1)")
        let days = ["Mo", "Di", "Mi", "Do", "Fr"]
        let lessons = Set(plan.lessons.map { "\(days[$0.day]) \($0.start)-\($0.end) \($0.course) \($0.roomLabel)" })
        let expected: Set<String> = [
            "Mo 3-4 bk2 BKOG", "Mo 5-6 E3 209", "Mo 8-8 S1 201", "Mo 9-9 D3 112", "Mo 10-11 S1 WB1",
            "Di 3-4 ch1 CHHS", "Di 5-6 D3 301", "Di 8-8 m1 109", "Di 11-11 esp 109",
            "Mi 1-2 kR1 310", "Mi 3-4 D3 301", "Mi 5-6 E3 409", "Mi 8-9 g2 323", "Mi 11-11 ch1 CHHS",
            "Do 1-2 S1 WB1", "Do 3-4 esp 310", "Do 8-8 E3 409", "Do 10-11 gk3 323",
            "Fr 3-4 m1 102", "Fr 5-6 psy1 403",
        ]
        #expect(lessons == expected)
    }

    @Test func basisSportIsOneCourseAcrossParallelSlots() throws {
        let choices: [CustomPlan.Choice] = [
            .init(subject: "M", level: .leistungsfach, hours: 5, parallel: 3),
            .init(subject: "Gk", level: .leistungsfach, hours: 5, parallel: nil),
            .init(subject: "Sport", level: .basisfach, hours: 2, parallel: nil),
        ]
        let plan = CustomPlanBuilder.build(name: "Test", choices: choices, konfession: nil, plan: try Self.stufenplan(),
                                           halbjahr: "1. Halbjahr", expectedTotal: 12)
        #expect(plan.courses.map(\.title) == ["Mathematik (LF, M3)", "Gemeinschaftskunde (LF)", "Sport (s1 / s2 / s3)"])
        #expect(plan.checks.ok)
        #expect(plan.lessons.first { $0.course == "s1/s2/s3" }?.roomLabel == "WB2 / FrEb / Less")
        #expect(plan.notes.count == 1)
    }

    @Test func overlappingCoursesAreReported() throws {
        let choices: [CustomPlan.Choice] = [
            .init(subject: "M", level: .leistungsfach, hours: 5, parallel: 3),
            .init(subject: "E", level: .leistungsfach, hours: 5, parallel: 1),
        ]
        let plan = CustomPlanBuilder.build(name: "", choices: choices, konfession: nil, plan: try Self.stufenplan(),
                                           halbjahr: "1. Halbjahr", expectedTotal: nil)
        #expect(plan.checks.issues.contains { $0.kind == .conflict && $0.codes == ["E1", "M3"] })
    }

    @Test func missingParallelCourseAndCandidates() throws {
        let stufenplan = try Self.stufenplan()
        let plan = CustomPlanBuilder.build(name: "", choices: [.init(subject: "D", level: .leistungsfach, hours: 5, parallel: 7)],
                                           konfession: nil, plan: stufenplan, halbjahr: "1. Halbjahr", expectedTotal: nil)
        #expect(plan.checks.issues.first?.kind == .notInPlan)
        #expect(CustomPlanBuilder.candidates(subject: "D", level: .leistungsfach, konfession: nil, plan: stufenplan) == ["D1", "D2", "D3"])
        #expect(CustomPlanBuilder.candidates(subject: "D", level: .basisfach, konfession: nil, plan: stufenplan) == ["d1", "d2", "d3"])
        #expect(CustomPlanBuilder.candidates(subject: "Rel", level: .basisfach, konfession: .evangelisch, plan: stufenplan) == ["eR1", "eR2"])
    }

    @Test func handPickedCodeWins() throws {
        let plan = CustomPlanBuilder.build(name: "", choices: [.init(subject: "M", level: .leistungsfach, hours: 5, parallel: 3, code: "M1")],
                                           konfession: nil, plan: try Self.stufenplan(), halbjahr: "1. Halbjahr", expectedTotal: nil)
        #expect(plan.courses.map(\.id) == ["M1"])
    }

    @Test func jsonRoundTripAndPdf() throws {
        let plan = CustomPlanBuilder.build(kurswahl: try Self.kurswahl(), plan: try Self.stufenplan(), halbjahr: "1. Halbjahr",
                                           now: Date(timeIntervalSince1970: 1_788_000_000))
        let json = try JSONEncoder().encode(plan)
        #expect(try JSONDecoder().decode(CustomPlan.self, from: json) == plan)

        let pdf = CustomPlanPDF.render(plan)
        #expect(String(decoding: pdf.prefix(5), as: UTF8.self) == "%PDF-")
        let page = try #require(PDFDocument(data: pdf)?.page(at: 0))
        let text = page.string ?? ""
        #expect(text.contains("Max Muster"))
        #expect(text.contains("Psychologie (psy1)"))
        #expect(text.contains("7:45–8:30"))
    }
}
