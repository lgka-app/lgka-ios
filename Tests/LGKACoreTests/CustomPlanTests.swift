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

    @Test func recognitionSlipsInCells() {
        #expect(KurswahlParser.tolerantCell("2.5").hours == 2 && KurswahlParser.tolerantCell("2.5").suffix == "s")
        #expect(KurswahlParser.tolerantCell("24)").hours == 2 && KurswahlParser.tolerantCell("24)").parallel == 4)
        #expect(KurswahlParser.tolerantCell("2(11").parallel == 1)
        // values that already read are untouched, unreadable text without a known slip stays unreadable
        #expect(KurswahlParser.tolerantCell("5(3)") == KurswahlParser.parseCell("5(3)"))
        #expect(KurswahlParser.tolerantCell("-") == KurswahlParser.parseCell("-"))
        #expect(KurswahlParser.tolerantCell("25").unreadable)
        #expect(KurswahlParser.tolerantCell("a7x").unreadable)
    }

    /// Two photos read nothing in Geographie's 1. Hj, one read "2.p" there (its columns one off):
    /// the 1. Hj would exceed its sum by exactly that cell, so it is not taken.
    @Test func mergeDropsASuffixCellThatBreaksTheSum() {
        func sheet(_ geo: [String?]) -> Kurswahl {
            Kurswahl(name: nil, abiturjahr: nil, konfession: nil, rows: [
                .init(subject: "M", fachart: "L", halves: ["5(3)", "5", "5", "5"].map(KurswahlParser.parseCell)),
                .init(subject: "Geo", fachart: "B", halves: geo.map { $0.map(KurswahlParser.parseCell) ?? .missing }),
            ], sums: [5, 7, 7, 5])
        }
        let merged = KurswahlParser.merge([sheet(["2.p", "2.s", nil, nil]), sheet([nil, "2.p", "2.s", "-"]), sheet(["-", "2.p", "2.s", nil])])
        #expect(merged.rows[1].halves[0].taken == false)
        #expect(merged.rows[1].halves[1].hours == 2 && merged.rows[1].halves[2].hours == 2)
        // agreed by two photos, or adding up: kept
        let agreed = KurswahlParser.merge([sheet(["2.p", "2.s", nil, nil]), sheet(["2.p", "2.s", nil, nil]), sheet([nil, nil, nil, nil])])
        #expect(agreed.rows[1].halves[0].hours == 2)
        // a plain value read by one photo only, equal to the excess, of a row the others found: dropped
        let plain = KurswahlParser.merge([sheet(["2", "2.s", nil, nil]), sheet([nil, "2.p", "2.s", "-"]), sheet([nil, "2.p", "2.s", nil])])
        #expect(plain.rows[1].halves[0].taken == false)
        // a required subject is never dropped
        func sport(_ first: String?) -> Kurswahl {
            Kurswahl(name: nil, abiturjahr: nil, konfession: nil, rows: [
                .init(subject: "M", fachart: "L", halves: ["5(3)", "5", "5", "5"].map(KurswahlParser.parseCell)),
                .init(subject: "Sport", fachart: "B", halves: [first, "2", "2", "2"].map { $0.map(KurswahlParser.parseCell) ?? .missing }),
            ], sums: [5, 7, 7, 7])
        }
        #expect(KurswahlParser.merge([sport("2"), sport(nil), sport(nil)]).rows[1].halves[0].hours == 2)
    }

    /// The sums line 36 / 36 / 34 / 46 / 36 taken one column late, and the 2. Hj sum unread: the
    /// columns are rebuilt from the brackets with the common gap, so the 1. Hj is 34 and the missing
    /// sum stays missing instead of pulling in "46".
    @Test func sumColumnsRebuiltFromTheBracketsWithAMissingSum() throws {
        var boxes = try JSONDecoder().decode([KurswahlScanner.Shot].self, from: Fixtures.data("kurswahl_scan_burst"))[1].boxes
        boxes.removeAll { $0.text == "36" && $0.midX > 0.59 && $0.midX < 0.63 && $0.midY > 0.7 }
        let kurswahl = try KurswahlParser.parse(boxes, aspect: 1.429)
        #expect(kurswahl.sums[0] == 34)
        #expect(!kurswahl.sums.contains(46))
        #expect(kurswahl.rows.first { $0.subject == "Geo" }?.halves.first?.taken == false)
    }

    /// A reading with the detection additions is kept only when its plan is not worse than the plan
    /// from the reading as it was always made.
    @Test func planFallsBackToTheOriginalReadingWhenAdditionsAddIssues() throws {
        let original = try Self.kurswahl()
        var additions = original
        // an addition that named nothing but added hours in an unnamed row
        additions.rows.append(.init(subject: "?", fachart: nil, halves: ["3(2)", "3", "3", "3"].map(KurswahlParser.parseCell)))
        additions.original = [original]
        let plan = CustomPlanBuilder.build(kurswahl: additions, plan: try Self.stufenplan(), halbjahr: "1. Halbjahr")
        #expect(plan.checks.issues.map(\.message) == [])
        #expect(plan.checks.totalHours == 34)
        // additions that fix the sheet win
        var broken = original
        if let d = broken.rows.firstIndex(where: { $0.subject == "D" }) { broken.rows[d].halves[0] = .missing }
        var fixed = original
        fixed.original = [broken]
        #expect(CustomPlanBuilder.build(kurswahl: fixed, plan: try Self.stufenplan(), halbjahr: "1. Halbjahr").checks.issues.isEmpty)
    }

    @Test func valueAndBracketReadApartAreJoined() {
        let boxes = [TextBox(text: "5", x: 0.50, y: 0.40, width: 0.008, height: 0.012),
                     TextBox(text: "(3)", x: 0.509, y: 0.401, width: 0.02, height: 0.012),
                     TextBox(text: "(2)", x: 0.80, y: 0.40, width: 0.02, height: 0.012)]
        let joined = KurswahlParser.joinedBrackets(boxes)
        // only the bracket right next to a digit on its line
        #expect(joined.map(\.text) == ["5(3)"])
        #expect(KurswahlParser.parseCell(joined[0].text).parallel == 3)
    }

    @Test func unknownRowOnlyTakesASubjectOfItsBlock() throws {
        #expect(CustomPlanBuilder.sheetBlock("Ph") == CustomPlanBuilder.sheetBlock("Ch"))
        #expect(CustomPlanBuilder.sheetBlock("Sport") != CustomPlanBuilder.sheetBlock("M"))
        // a 3 hour row between Geschichte and Religion is a subject of one of those blocks, never a science
        let sheet = Kurswahl(name: nil, abiturjahr: nil, konfession: .katholisch, rows: [
            .init(subject: "E", fachart: "L", halves: ["5(3)", "5", "5", "5"].map(KurswahlParser.parseCell)),
            .init(subject: "G", fachart: "B", halves: ["2(2)", "2", "2", "2"].map(KurswahlParser.parseCell)),
            .init(subject: "?", fachart: "B", halves: ["3(1)", "3", "3", "3"].map(KurswahlParser.parseCell)),
            .init(subject: "Rel", fachart: "B", halves: ["2(1)", "2", "2", "2"].map(KurswahlParser.parseCell)),
        ], sums: [nil, nil, nil, nil])
        let plan = CustomPlanBuilder.build(kurswahl: sheet, plan: try Self.stufenplan(), halbjahr: "1. Halbjahr")
        #expect(!plan.choices.contains { ["Bio", "Ph", "Ch", "NwT", "M"].contains($0.subject) })
        #expect(plan.checks.issues.contains { $0.kind == .unknownRow })
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

    @Test func missingSubjectIsRecoveredFromThePlan() throws {
        var boxes = try JSONDecoder().decode([TextBox].self, from: Fixtures.data("kurswahl_ocr"))
        boxes.removeAll { $0.text == "D" || $0.text.lowercased().hasPrefix("summen") }
        let kurswahl = try KurswahlParser.parse(boxes)
        // no "Summen" label: the numbers under the table still give the sums
        #expect(kurswahl.sums.first == 34)
        // Deutsch is the first row: found in the gap under the table header, named by the only course that fits
        let plan = CustomPlanBuilder.build(kurswahl: kurswahl, plan: try Self.stufenplan(), halbjahr: "1. Halbjahr")
        #expect(plan.checks.issues.map(\.message) == [])
        #expect(plan.courses.contains { $0.id == "D3" })
        #expect(plan.checks.totalHours == 34)
    }

    @Test func unreadableSumIsReported() throws {
        var boxes = try JSONDecoder().decode([TextBox].self, from: Fixtures.data("kurswahl_ocr"))
        boxes.removeAll { $0.text.lowercased().hasPrefix("summen") || ($0.y > 0.87 && $0.text.wholeMatch(of: #/\d{2}/#) != nil) }
        let plan = CustomPlanBuilder.build(kurswahl: try KurswahlParser.parse(boxes), plan: try Self.stufenplan(), halbjahr: "1. Halbjahr")
        #expect(plan.checks.issues.contains { $0.kind == .sumUnreadable })
        #expect(plan.checks.totalHours == 34)
    }

    @Test func tiltedPhotoStillFindsColumnsAndSums() throws {
        // about 2.3° clockwise: the right edge sits 4 % of the height lower than the left
        let boxes = try JSONDecoder().decode([TextBox].self, from: Fixtures.data("kurswahl_ocr")).map { box -> TextBox in
            var tilted = box
            tilted.y += (box.midX - 0.5) * 0.04
            return tilted
        }
        let kurswahl = try KurswahlParser.parse(boxes)
        #expect(kurswahl.sums.first == 34)
        let plan = CustomPlanBuilder.build(kurswahl: kurswahl, plan: try Self.stufenplan(), halbjahr: "1. Halbjahr")
        #expect(plan.checks.issues.map(\.message) == [])
        #expect(plan.checks.totalHours == 34)
    }

    /// A second real sheet (iPhone photo): "D", "E" and "Summen" were not recognised at all.
    @Test func sheetWithUnrecognisedSubjectsAndSumLabel() throws {
        let kurswahl = try KurswahlParser.parse(JSONDecoder().decode([TextBox].self, from: Fixtures.data("kurswahl_ocr_b")))
        #expect(kurswahl.sums.first == 34)
        let plan = CustomPlanBuilder.build(kurswahl: kurswahl, plan: try Self.stufenplan(), halbjahr: "1. Halbjahr")
        #expect(plan.checks.issues.map(\.message) == [])
        #expect(Set(plan.courses.map(\.id)) == ["d3", "E4", "GK", "mus2", "g4", "kR1", "M3", "bio2", "ph", "inf1", "s1/s2/s3"])
        #expect(plan.checks.totalHours == 34)
    }

    /// The same sheet scanned in the app (camera, perspective-corrected): the Sport row's "2" in the
    /// 1. Hj column was not recognised at all, only the "-" of the "bes. Lernleistung" row below.
    /// Sport is required every Halbjahr, so its "pro Kurs" 2 fills the gap, marked for checking.
    @Test func phoneScanFillsRequiredSubjectFromPerCourse() throws {
        let kurswahl = try KurswahlParser.parse(JSONDecoder().decode([TextBox].self, from: Fixtures.data("kurswahl_ocr_c")),
                                                aspect: 1.5092336103416435)
        let sport = kurswahl.rows.first { $0.subject == "Sport" }?.halves.first
        #expect(sport?.hours == 2 && sport?.inferred == true)
        let plan = CustomPlanBuilder.build(kurswahl: kurswahl, plan: try Self.stufenplan(), halbjahr: "1. Halbjahr")
        #expect(plan.checks.issues.map(\.kind) == [.inferred])
        #expect(plan.checks.totalHours == 34)
    }

    /// A three-photo burst from the app (name replaced, SchNr, SchID and birth date removed). In the
    /// first photo the sums line search took 36 / 36 / 34 / 46 (one column late, "anrechenbar" as
    /// the 4. Hj), so Geographie's "2.p" landed in the 1. Hj and the plan came out at 39 hours.
    /// A second burst of that sheet (42 hours in the app): again one photo's columns one off, with
    /// Geographie's "2.p" in its 1. Hj.
    @Test(arguments: ["kurswahl_scan_burst", "kurswahl_scan_burst_b", "kurswahl_scan_burst_c"])
    func burstWithSumsOneColumnLate(fixture: String) throws {
        let shots = try JSONDecoder().decode([KurswahlScanner.Shot].self, from: Fixtures.data(fixture))
        #expect(shots.count == 3)
        let sheets = try shots.map { try KurswahlParser.parse($0.boxes, aspect: $0.aspect) }
        for sheet in sheets { #expect(sheet.sums == [34, 36, 36, 34]) }
        let merged = KurswahlParser.merge(sheets)
        #expect(merged.rows.first { $0.subject == "Geo" }?.halves.first?.taken == false)
        let plan = CustomPlanBuilder.build(kurswahl: merged, plan: try Self.stufenplan(), halbjahr: "1. Halbjahr")
        #expect(!plan.courses.contains { $0.subjectKey == "Geo" })
        #expect(!plan.checks.issues.contains { $0.kind == .conflict || $0.kind == .totalMismatch })
        #expect(plan.checks.totalHours == 34)
    }

    @Test func overviewAndCloseUpsMerge() throws {
        let boxes = try JSONDecoder().decode([TextBox].self, from: Fixtures.data("kurswahl_ocr"))
        // stand-ins for close-ups: the upper and the lower part of the table, each with its own gaps
        let top = boxes.filter { $0.y < 0.66 && $0.text != "Ph" }
        let bottom = boxes.filter { $0.y > 0.55 || $0.text.contains("Abiturjahr") }
        let overview = boxes.filter { $0.text != "D" && $0.text != "5(1)" }
        let sheets = [overview, top, bottom].compactMap { try? KurswahlParser.parse($0) }
        #expect(sheets.count == 3)
        let merged = KurswahlParser.merge(sheets)
        #expect(merged.rows.first { $0.subject == "D" }?.halves.first?.parallel == 3)
        #expect(merged.rows.first { $0.subject == "Sport" }?.halves.first?.parallel == 1)
        #expect(merged.sums.first == 34)
        let plan = CustomPlanBuilder.build(kurswahl: merged, plan: try Self.stufenplan(), halbjahr: "1. Halbjahr")
        #expect(plan.checks.issues.map(\.message) == [])
        #expect(plan.checks.totalHours == 34)
    }

    @Test func missingHalfIsTakenFromTheOtherThree() {
        let cells = ["-", "2", "2", "2"].map(KurswahlParser.parseCell)
        var halves = cells
        halves[0] = .missing
        let inferred = KurswahlParser.inferMissing(halves, perCourse: "2")
        #expect(inferred[0].hours == 2 && inferred[0].inferred == true)
        // a two-Halbjahr subject is not filled in
        let geo = KurswahlParser.inferMissing([.missing, KurswahlParser.parseCell("2.p"), KurswahlParser.parseCell("2.s"), .missing], perCourse: "2")
        #expect(geo[0].taken == false)
        // an explicit dash stays a dash
        #expect(KurswahlParser.inferMissing(cells, perCourse: "2")[0].taken == false)
    }

    /// Nothing of Sport's row was read but its Fachart: Basisfach 2 hours, Leistungsfach 5.
    @Test func sportHoursFromFachartWhenNothingElseWasRead() {
        #expect(KurswahlParser.sportHours(fachart: "B") == 2)
        #expect(KurswahlParser.sportHours(fachart: "L") == 5)
        #expect(KurswahlParser.sportHours(fachart: nil) == nil)
        let empty = [Kurswahl.Cell](repeating: .missing, count: 4)
        let filled = KurswahlParser.inferMissing(empty, perCourse: nil, allHalves: true, fallbackHours: 5)
        #expect(filled.allSatisfy { $0.hours == 5 && $0.inferred == true })
        // a Halbjahr that was read still decides over the Fachart
        let read = KurswahlParser.inferMissing([.missing, KurswahlParser.parseCell("2"), .missing, .missing],
                                               perCourse: nil, allHalves: true, fallbackHours: 5)
        #expect(read[0].hours == 2)
        // without a fallback nothing changes
        #expect(KurswahlParser.inferMissing(empty, perCourse: nil, allHalves: true).allSatisfy { !$0.taken })
    }

    @Test func sumFillsTheOneCellThatIsMissing() {
        func row(_ subject: String, _ cells: [String?], perCourse: String? = nil) -> Kurswahl.Row {
            .init(subject: subject, fachart: nil, halves: cells.map { $0.map(KurswahlParser.parseCell) ?? .missing }, perCourse: perCourse)
        }
        let sheet = Kurswahl(name: nil, abiturjahr: nil, konfession: nil, rows: [
            row("Bio", [nil, "3", "3", "3"]),
            row("Inf", ["2(1)", "2", "2", "2"]),
            row("Ast", [nil, nil, nil, nil], perCourse: "2"),
            row("Geo", ["-", "2.p", "2.s", nil]),
        ], sums: [5, 5, 7, 5])
        let repaired = KurswahlParser.repairWithSums(sheet)
        // 1. Hj: 2 read, sum 5 → Biologie's usual 3 fills the gap
        #expect(repaired.rows[0].halves[0].hours == 3 && repaired.rows[0].halves[0].inferred == true)
        // a subject never taken and a two-Halbjahr subject are not candidates
        #expect(repaired.rows[2].halves.allSatisfy { !$0.taken })
        #expect(repaired.rows[3].halves[3].taken == false)
        // sums that already add up leave everything as it was
        #expect(Array(repaired.rows[1...]) == Array(sheet.rows[1...]))

        // two rows that would fit equally: nothing is guessed
        var twice = sheet
        twice.rows.append(row("Ch", [nil, "3", "3", "3"]))
        twice.sums = [5, 8, 10, 8]
        #expect(KurswahlParser.repairWithSums(twice).rows[0].halves[0].taken == false)
        // a dash that was read is never overwritten
        var dash = sheet
        dash.rows[0].halves[0] = KurswahlParser.parseCell("-")
        #expect(KurswahlParser.repairWithSums(dash).rows[0].halves[0].taken == false)
    }

    @Test func secondReadingOnlyFillsGaps() {
        func row(_ subject: String, _ cells: [String?]) -> Kurswahl.Row {
            .init(subject: subject, fachart: nil, halves: cells.map { $0.map(KurswahlParser.parseCell) ?? .missing })
        }
        var sportInferred = row("Sport", [nil, "2", "2", "2"])
        sportInferred.halves[0] = .init(raw: nil, hours: 2, parallel: nil, unreadable: false, inferred: true)
        let base = Kurswahl(name: nil, abiturjahr: nil, konfession: nil, rows: [
            row("D", [nil, "3", "3", "3"]),
            row("?", ["5(4)", "5", "5", nil]),
            row("M", ["5(3)", "5", nil, "5"]),
            row("Geo", ["-", "2.p", "2.s", "-"]),
            sportInferred,
        ], sums: [nil, 36, 36, 34])
        let other = Kurswahl(name: nil, abiturjahr: nil, konfession: nil, rows: [
            row("D", ["3(3)", "3", "3", "3"]),
            row("E", ["5(4)", "5", "5", "5"]),
            row("M", ["5(1)", "3", "5", "5"]),
            row("Geo", ["2", "2.p", "2.s", "-"]),
            row("Sport", ["2", "2", "2", "2"]),
            row("Inf", ["2(1)", "2", "2", "2"]),
        ], sums: [34, 36, 36, 34])
        let filled = KurswahlParser.fillGaps(base, from: other)
        #expect(filled.rows.map(\.subject) == ["D", "E", "M", "Geo", "Sport", "Inf"])
        #expect(filled.rows[0].halves[0].hours == 3 && filled.rows[0].halves[0].parallel == 3)
        // the unnamed row follows D and its hours agree: Englisch; its unread 4. Hj is filled
        #expect(filled.rows[1].halves[3].hours == 5)
        // read values stay even where the second reading differs
        #expect(filled.rows[2].halves[0].parallel == 3 && filled.rows[2].halves[1].hours == 5)
        #expect(filled.rows[2].halves[2].hours == 5)
        // a dash that was read stays a dash
        #expect(filled.rows[3].halves[0].taken == false)
        // an inferred value confirmed by a reading becomes a read value
        #expect(filled.rows[4].halves[0].hours == 2 && filled.rows[4].halves[0].inferred == nil)
        #expect(filled.sums == [34, 36, 36, 34])
    }

    @Test func consistencyPrefersAReadingThatAddsUp() throws {
        let sheet = try Self.kurswahl()
        var broken = sheet
        if let d = broken.rows.firstIndex(where: { $0.subject == "D" }) { broken.rows[d].halves[0] = .missing }
        #expect(KurswahlParser.consistency(sheet) > KurswahlParser.consistency(broken))
        #expect(!KurswahlParser.isComplete(broken))
    }

    /// The second Halbjahr column reads "5", not "5(3)": the course number carries over from the first.
    @Test func secondHalbjahrKeepsTheParallelCourse() throws {
        let kurswahl = try Self.kurswahl()
        let (choices, _) = CustomPlanBuilder.choices(from: kurswahl, half: 1)
        #expect(choices.first { $0.subject == "D" }?.parallel == 3)
        #expect(choices.first { $0.subject == "E" }?.parallel == 3)
        // Geo starts in the second Halbjahr ("2.p"): nothing to carry over
        #expect(choices.first { $0.subject == "Geo" }?.parallel == nil)
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
