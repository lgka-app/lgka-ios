import Foundation
import CoreGraphics
import LGKACore
import LGKAPlanKit

/// Command line for the custom J11 / J12 timetable, the same code the app runs:
///
///   lgka-plan build --plan J11.pdf [--plan J12.pdf] --kurswahl photo.jpg [--halbjahr "1. Halbjahr"] --out plan.json
///   lgka-plan render plan.json plan.pdf
///   lgka-plan stufenplan J11.pdf        (parsed Stufenplan as JSON)
///   lgka-plan kurswahl photo.jpg        (parsed Kurswahlprotokoll as JSON)
///   lgka-plan words J11.pdf | ocr photo.jpg   (raw positioned text, for fixtures)
@main
struct LGKAPlanCommand {
    static func main() async {
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    static func run(_ args: [String]) async throws {
        guard let command = args.first else { throw Usage() }
        let rest = Array(args.dropFirst())
        switch command {
        case "build":
            let plans = values(rest, "--plan")
            guard !plans.isEmpty, let out = values(rest, "--out").first else { throw Usage() }
            let halbjahr = values(rest, "--halbjahr").first ?? "1. Halbjahr"
            let stufenplaene = try plans.map { try PdfText.stufenplan(at: URL(fileURLWithPath: $0)) }
            let kurswahl: Kurswahl
            if let scanPath = values(rest, "--scan").first {
                // recognised text saved by a debug build of the app (last-scan.json), parsed again
                let scan = try JSONDecoder().decode(KurswahlScanner.Result.self, from: Data(contentsOf: URL(fileURLWithPath: scanPath)))
                let shots = scan.shots ?? [.init(boxes: scan.boxes, aspect: scan.aspect)]
                let sheets = shots.compactMap { try? KurswahlParser.parse($0.boxes, aspect: $0.aspect) }
                var merged = sheets.count > 1 ? KurswahlParser.repairWithSums(KurswahlParser.merge(sheets)) : KurswahlParser.merge(sheets)
                // the reading as it was always made, like the app's scanner keeps it
                let originalSheets = shots.compactMap { try? KurswahlParser.parseDetailed($0.boxes, aspect: $0.aspect, enhanced: false).kurswahl }
                let original = KurswahlParser.merge(originalSheets, guards: false)
                if !originalSheets.isEmpty, original != merged { merged.original = [original] }
                kurswahl = merged
            } else if !values(rest, "--kurswahl").isEmpty {
                // several --kurswahl photos of one sheet (overview, close-ups) are merged
                kurswahl = try await KurswahlScanner.read(try values(rest, "--kurswahl").map { try image($0) }).kurswahl
            } else {
                throw Usage()
            }
            // the Stufenplan of the sheet's Jahrgang when several are given
            let plan = stufenplaene.first { p in
                p.schuljahr.flatMap { kurswahl.grade(inSchuljahr: $0) } == p.grade
            } ?? stufenplaene[0]
            if let kurswahlOut = values(rest, "--kurswahl-out").first {
                try encoder().encode(kurswahl).write(to: URL(fileURLWithPath: kurswahlOut))
            }
            var result = CustomPlanBuilder.build(kurswahl: kurswahl, plan: plan, halbjahr: halbjahr)
            if let name = values(rest, "--name").first { result.name = name }
            try write(result, to: out)
            report(result)
        case "render":
            let files = rest.filter { $0 != "--english" }
            guard files.count == 2 else { throw Usage() }
            let plan = try JSONDecoder().decode(CustomPlan.self, from: Data(contentsOf: URL(fileURLWithPath: files[0])))
            let labels = rest.contains("--english") ? Self.english : .german
            try CustomPlanPDF.render(plan, labels: labels).write(to: URL(fileURLWithPath: files[1]))
            print("wrote \(rest[1])")
        case "stufenplan":
            guard let path = rest.first else { throw Usage() }
            try printJSON(PdfText.stufenplan(at: URL(fileURLWithPath: path)))
        case "kurswahl":
            guard let path = rest.first else { throw Usage() }
            try printJSON(try await KurswahlScanner.read(try image(path)).kurswahl)
        case "words":
            guard let path = rest.first, let document = PDFDocumentLoader.page(path) else { throw Usage() }
            try printJSON(PdfText.words(in: document))
        case "ocr":
            guard let path = rest.first else { throw Usage() }
            try printJSON(try await KurswahlScanner.read(try image(path)).boxes)
        case "parse-debug":
            // a recorded scan read both ways (as always, and with the additions) and which one was taken
            guard let path = rest.first else { throw Usage() }
            let scan = try JSONDecoder().decode(KurswahlScanner.Result.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
            for (index, shot) in (scan.shots ?? [.init(boxes: scan.boxes, aspect: scan.aspect)]).enumerated() {
                func describe(_ label: String, _ detail: KurswahlParser.Detail?) {
                    guard let detail else { return print("  \(label): no table") }
                    let k = detail.kurswahl
                    print("  \(label): sums \(k.sums) matched \(KurswahlParser.matchedSums(k)) rebuilt \(detail.columnsRebuilt)")
                    for row in k.rows {
                        let cells = row.halves.map { c in (c.raw ?? "·") + (c.hours.map { "=\($0)" } ?? "") + (c.inferred == true ? "i" : "") }
                        print("    \(row.subject.padding(toLength: 6, withPad: " ", startingAt: 0)) \(cells.joined(separator: " | "))")
                    }
                }
                print("shot \(index + 1)")
                describe("legacy", try? KurswahlParser.parseDetailed(shot.boxes, aspect: shot.aspect, enhanced: false))
                describe("enhanced", try? KurswahlParser.parseDetailed(shot.boxes, aspect: shot.aspect, enhanced: true))
                describe("chosen", try? KurswahlParser.parseDetailed(shot.boxes, aspect: shot.aspect))
            }
        case "ocr-region":
            // text recognised in one region (0…1, top-left) the way the scanner's extra passes read it
            guard rest.count >= 5, let x = Double(rest[1]), let y = Double(rest[2]), let w = Double(rest[3]), let h = Double(rest[4]) else { throw Usage() }
            let options = KurswahlScanner.PassOptions(contrast: rest.contains("--contrast"),
                                                      maxScale: values(rest, "--scale").first.flatMap(Double.init) ?? 3)
            try printJSON(try await KurswahlScanner.recognize(try image(rest[0]), region: CGRect(x: x, y: y, width: w, height: h), options: options))
        default:
            throw Usage()
        }
    }

    struct Usage: Error, CustomStringConvertible {
        var description: String {
            """
            usage:
              lgka-plan build --plan J11.pdf [--plan J12.pdf] --kurswahl photo.jpg [--halbjahr "1. Halbjahr"] [--name "Vorname Nachname"] --out plan.json
              lgka-plan render plan.json plan.pdf
              lgka-plan stufenplan plan.pdf | kurswahl photo.jpg | words plan.pdf | ocr photo.jpg
            """
        }
    }

    /// The PDF's words in English (the app uses its string catalog instead).
    static let english = CustomPlanPDF.Labels(
        title: "Personal timetable",
        schoolYear: { "School year \($0)" },
        stand: { "As of \($0)" },
        room: { "Room \($0)" },
        days: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
        halbjahr: { $0.hasPrefix("1") ? "1st semester" : $0.hasPrefix("2") ? "2nd semester" : $0 },
        footer: { "Bell times from school year 2025/26 (school rules, 2025). Long breaks: \($0)" },
        courseTitle: { course in
            let name = englishSubject(course)
            if course.codes.count > 1 { return "\(name) (\(course.codes.joined(separator: " / ")))" }
            let code = course.codes.first ?? course.id
            guard course.level == .leistungsfach else { return "\(name) (\(code))" }
            return CourseCode(code)?.number != nil ? "\(name) (adv., \(code))" : "\(name) (adv.)"
        },
        sharedSlotsNote: { "\(englishSubject($0)): \($0.codes.joined(separator: " / ")) not stated on the course selection record, all at the same time" })

    static func englishSubject(_ course: CustomPlan.Course) -> String {
        let stem = course.codes.first.flatMap(CourseCode.init)?.stem
        if course.subjectKey == "Rel" { return stem == "er" ? "Protestant RE" : stem == "kr" ? "Catholic RE" : "Religious Education" }
        let names = ["D": "German", "E": "English", "F": "French", "Sp": "Spanish", "L": "Latin", "I": "Italian", "BK": "Art",
                     "Mu": "Music", "G": "History", "Gk": "Social Studies", "Geo": "Geography", "WBS": "Economics", "Eth": "Ethics",
                     "Phil": "Philosophy", "M": "Maths", "Bio": "Biology", "Ph": "Physics", "Ch": "Chemistry",
                     "NwT": "Science and Technology", "Inf": "Computer Science", "Sport": "PE", "Psy": "Psychology",
                     "Ast": "Astronomy", "LTh": "Literature and Theatre"]
        return names[course.subjectKey] ?? course.subject
    }

    private static func values(_ args: [String], _ flag: String) -> [String] {
        args.indices.compactMap { i in args[i] == flag && i + 1 < args.count ? args[i + 1] : nil }
    }

    private static func image(_ path: String) throws -> CGImage {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let image = KurswahlScanner.image(from: data) else { throw CocoaError(.fileReadCorruptFile) }
        return image
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return encoder
    }

    private static func printJSON(_ value: some Encodable) throws {
        print(String(decoding: try encoder().encode(value), as: UTF8.self))
    }

    private static func write(_ plan: CustomPlan, to path: String) throws {
        try encoder().encode(plan).write(to: URL(fileURLWithPath: path))
    }

    private static func report(_ plan: CustomPlan) {
        var lines = ["\(plan.name.isEmpty ? "(ohne Namen)" : plan.name) · \(plan.stufe) · \(plan.halbjahr)"]
        for course in plan.courses {
            let expected = course.expectedHours.map { $0 == course.hours ? "" : " (Kurswahl: \($0))" } ?? ""
            lines.append("  \(course.title.padding(toLength: 34, withPad: " ", startingAt: 0)) \(course.hours) Std.\(expected)  \(course.teacherLabel)")
        }
        lines.append("Summe \(plan.checks.totalHours) Std." + (plan.checks.expectedTotal.map { " (Kurswahl: \($0))" } ?? ""))
        lines.append(plan.checks.ok ? "Prüfung: alles passt" : "Prüfung:\n" + plan.checks.issues.map { "  ! \($0.message)" }.joined(separator: "\n"))
        FileHandle.standardError.write(Data((lines.joined(separator: "\n") + "\n").utf8))
    }
}
