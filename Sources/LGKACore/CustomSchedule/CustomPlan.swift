import Foundation

/// A personal J11 / J12 timetable: everything needed to draw it (in the app or as a PDF),
/// self-contained, plus the course choices it was built from so a newer Stufenplan can
/// rebuild it without scanning the Kurswahlprotokoll again.
public struct CustomPlan: Codable, Hashable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var name: String
    /// "J11".
    public var stufe: String
    /// "1. Halbjahr".
    public var halbjahr: String
    public var schuljahr: String?
    /// Untis export time of the Stufenplan the lessons come from.
    public var stand: String?
    public var periods: [SchoolReference.Period]
    public var breaks: [SchoolReference.Break]
    public var courses: [Course]
    public var lessons: [Lesson]
    public var choices: [Choice]
    public var checks: Checks
    /// Short remarks for the plan's footer ("Sport: s1 / s2 / s3 …").
    public var notes: [String]
    /// ISO 8601.
    public var generatedAt: String
    /// sha256 of the Stufenplan PDF, to notice a newer plan.
    public var planSha256: String?

    public enum Level: String, Codable, Hashable, Sendable {
        case leistungsfach = "LF"
        case basisfach = "Basis"
    }

    public struct Course: Codable, Hashable, Sendable, Identifiable {
        /// The course code, or the codes joined with "/" when several parallel courses share every slot.
        public var id: String
        public var subjectKey: String
        /// "Mathematik", "kath. Religion".
        public var subject: String
        public var level: Level
        public var codes: [String]
        /// "Mathematik (LF, M3)", "Gemeinschaftskunde (LF)", "Sport (s1 / s2 / s3)".
        public var title: String
        public var teachers: [Teacher]
        /// Weekly hours in the Stufenplan.
        public var hours: Int
        /// Weekly hours according to the Kurswahlprotokoll.
        public var expectedHours: Int?

        /// "Johannes Burger"; last names joined for several teachers ("Burger / Domin / Bachmor").
        public var teacherLabel: String {
            if teachers.count == 1 { return teachers[0].name ?? teachers[0].code }
            return teachers.map { $0.name.map { n in n.split(separator: " ").last.map(String.init) ?? n } ?? $0.code }
                .joined(separator: " / ")
        }
    }

    public struct Teacher: Codable, Hashable, Sendable {
        public var code: String
        public var name: String?
    }

    public struct Lesson: Codable, Hashable, Sendable {
        /// 0 = Montag … 4 = Freitag.
        public var day: Int
        public var start: Int
        public var end: Int
        public var course: String
        public var rooms: [String]
        public var teachers: [String]

        public var roomLabel: String { rooms.joined(separator: " / ") }
        public var hours: Int { end - start + 1 }
    }

    /// One subject as chosen in the Kurswahlprotokoll (or corrected by the user).
    public struct Choice: Codable, Hashable, Sendable, Identifiable {
        public var subject: String
        public var level: Level
        public var hours: Int
        public var parallel: Int?
        /// A course code picked by hand; wins over the automatic match.
        public var code: String?

        public var id: String { subject }

        public init(subject: String, level: Level, hours: Int, parallel: Int?, code: String? = nil) {
            self.subject = subject
            self.level = level
            self.hours = hours
            self.parallel = parallel
            self.code = code
        }
    }

    public struct Checks: Codable, Hashable, Sendable {
        public var totalHours: Int
        public var expectedTotal: Int?
        public var issues: [Issue]
        public var ok: Bool { issues.isEmpty }
    }

    public struct Issue: Codable, Hashable, Sendable {
        public enum Kind: String, Codable, Hashable, Sendable {
            case unreadable, notInPlan, ambiguous, hoursMismatch, totalMismatch, conflict, gradeMismatch
        }
        public var kind: Kind
        public var subject: String?
        public var codes: [String]
        /// German, for the JSON and the command line; the app words it itself.
        public var message: String
    }

    public static let dayNames = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"]
}

public enum CustomPlanBuilder {
    /// The subjects taken in one Halbjahr, with the sheet's unreadable cells as issues.
    public static func choices(from kurswahl: Kurswahl, half: Int) -> (choices: [CustomPlan.Choice], issues: [CustomPlan.Issue]) {
        var choices: [CustomPlan.Choice] = []
        var issues: [CustomPlan.Issue] = []
        for row in kurswahl.rows {
            guard half < row.halves.count else { continue }
            let cell = row.halves[half]
            if cell.unreadable {
                // an empty cell next to an unreadable one is common for subjects never taken;
                // only a cell with some text is worth asking about
                if cell.raw != nil {
                    issues.append(.init(kind: .unreadable, subject: row.subject, codes: [],
                                        message: "\(subjectName(row.subject)): Eintrag „\(cell.raw ?? "")“ im Kurswahlprotokoll nicht lesbar"))
                }
                continue
            }
            guard let hours = cell.hours else { continue }
            let level: CustomPlan.Level = switch row.fachart {
            case "L": .leistungsfach
            case "B", "m": .basisfach
            default: hours >= 5 ? .leistungsfach : .basisfach
            }
            choices.append(.init(subject: row.subject, level: level, hours: hours, parallel: cell.parallel))
        }
        return (choices, issues)
    }

    /// Kurswahlprotokoll + Stufenplan → plan.
    public static func build(kurswahl: Kurswahl, plan: Stufenplan, halbjahr: String,
                             planSha256: String? = nil, now: Date = Date()) -> CustomPlan {
        let grade = plan.grade ?? 11
        let half = Kurswahl.halfIndex(grade: grade, halbjahr: halbjahr)
        var (choices, issues) = Self.choices(from: kurswahl, half: half)
        if let schuljahr = plan.schuljahr, let sheetGrade = kurswahl.grade(inSchuljahr: schuljahr), sheetGrade != grade {
            issues.append(.init(kind: .gradeMismatch, subject: nil, codes: [],
                                message: "Das Kurswahlprotokoll gehört zu J\(sheetGrade), der Stundenplan ist \(plan.stufe)"))
        }
        choices.sort { order($0.subject) < order($1.subject) }
        return build(name: kurswahl.name ?? "", choices: choices, konfession: kurswahl.konfession, plan: plan,
                     halbjahr: halbjahr, expectedTotal: half < kurswahl.sums.count ? kurswahl.sums[half] : nil,
                     extraIssues: issues, planSha256: planSha256, now: now)
    }

    /// Choices → plan. Used after scanning and again whenever the user corrects a course.
    public static func build(name: String, choices: [CustomPlan.Choice], konfession: Kurswahl.Konfession?,
                             plan: Stufenplan, halbjahr: String, expectedTotal: Int?,
                             extraIssues: [CustomPlan.Issue] = [], planSha256: String? = nil,
                             now: Date = Date()) -> CustomPlan {
        var issues = extraIssues
        var courses: [CustomPlan.Course] = []
        var lessons: [CustomPlan.Lesson] = []
        var notes: [String] = []

        for choice in choices {
            let resolution = resolve(choice, konfession: konfession, plan: plan)
            let name = subjectName(choice.subject)
            switch resolution {
            case .problem(let issue):
                issues.append(issue)
            case .courses(let codes):
                let slots = codes.flatMap { plan.slots(for: $0) }
                let subject = SchoolReference.subjectName(key: choice.subject, code: codes[0])
                let id = codes.joined(separator: "/")
                var courseLessons: [CustomPlan.Lesson] = []
                for slot in slots {
                    if let i = courseLessons.firstIndex(where: { $0.day == slot.day && $0.start == slot.start && $0.end == slot.end }) {
                        if let room = slot.room, !courseLessons[i].rooms.contains(room) { courseLessons[i].rooms.append(room) }
                        if let t = slot.teacher, !courseLessons[i].teachers.contains(t) { courseLessons[i].teachers.append(t) }
                    } else {
                        courseLessons.append(.init(day: slot.day, start: slot.start, end: slot.end, course: id,
                                                   rooms: slot.room.map { [$0] } ?? [], teachers: slot.teacher.map { [$0] } ?? []))
                    }
                }
                var teacherCodes: [String] = []
                for t in slots.compactMap(\.teacher) where !teacherCodes.contains(t) { teacherCodes.append(t) }
                let hours = courseLessons.reduce(0) { $0 + $1.hours }
                let course = CustomPlan.Course(
                    id: id, subjectKey: choice.subject, subject: subject, level: choice.level, codes: codes,
                    title: title(subject: subject, level: choice.level, codes: codes),
                    teachers: teacherCodes.map { .init(code: $0, name: SchoolReference.teacherName($0)) },
                    hours: hours, expectedHours: choice.hours)
                if hours != choice.hours {
                    issues.append(.init(kind: .hoursMismatch, subject: choice.subject, codes: codes,
                                        message: "\(course.title): \(hours) Std. im Stundenplan, laut Kurswahl \(choice.hours) Std."))
                }
                if codes.count > 1 {
                    notes.append("\(name): \(codes.joined(separator: " / ")) im Kurswahlprotokoll nicht vermerkt, alle zur selben Zeit")
                }
                courses.append(course)
                lessons.append(contentsOf: courseLessons)
            }
        }

        // two courses in the same period means one of them was matched wrongly
        var byPeriod: [String: [String]] = [:]
        for lesson in lessons {
            for p in lesson.start...lesson.end {
                byPeriod["\(lesson.day)-\(p)", default: []].append(lesson.course)
            }
        }
        var reported = Set<[String]>()
        for day in 0..<5 {
            for p in 1...15 {
                guard let ids = byPeriod["\(day)-\(p)"], Set(ids).count > 1 else { continue }
                let pair = Array(Set(ids)).sorted()
                guard reported.insert(pair).inserted else { continue }
                let titles = pair.map { id in courses.first { $0.id == id }?.title ?? id }
                issues.append(.init(kind: .conflict, subject: nil, codes: pair,
                                    message: "\(CustomPlan.dayNames[day]) \(p). Std.: \(titles.joined(separator: " und ")) gleichzeitig"))
            }
        }

        let total = lessons.reduce(0) { $0 + $1.hours }
        if let expectedTotal, expectedTotal != total {
            issues.append(.init(kind: .totalMismatch, subject: nil, codes: [],
                                message: "Summe \(total) Std., laut Kurswahlprotokoll \(expectedTotal) Std."))
        }
        let sortedLessons = lessons.sorted { a, b in
            if a.day != b.day { return a.day < b.day }
            return a.start < b.start
        }
        let formatter = ISO8601DateFormatter()
        return CustomPlan(version: CustomPlan.currentVersion, name: name, stufe: plan.stufe, halbjahr: halbjahr,
                          schuljahr: plan.schuljahr, stand: plan.stand,
                          periods: SchoolReference.periods, breaks: SchoolReference.breaks,
                          courses: courses, lessons: sortedLessons, choices: choices,
                          checks: .init(totalHours: total, expectedTotal: expectedTotal, issues: issues),
                          notes: notes, generatedAt: formatter.string(from: now), planSha256: planSha256)
    }

    /// Every course of the plan a subject could be at a level ("M", LF → M1, M2, M3).
    public static func candidates(subject: String, level: CustomPlan.Level?, konfession: Kurswahl.Konfession?,
                                  plan: Stufenplan) -> [String] {
        var stems = SchoolReference.subject(subject)?.stems ?? [subject.lowercased()]
        if subject == "Rel" {
            switch konfession {
            case .katholisch: stems = ["kr"]
            case .evangelisch: stems = ["er"]
            case nil: break
            }
        }
        let all = plan.codes.compactMap(CourseCode.init).filter { stems.contains($0.stem) }
        guard let level else { return all.map(\.code).sorted() }
        // Untis capitalises Leistungsfach codes; a stem written only one way (LTh, kR) is not a hint
        let hasBoth = Set(all.map(\.capitalised)).count == 2
        let atLevel = hasBoth ? all.filter { $0.capitalised == (level == .leistungsfach) } : all
        return atLevel.map(\.code).sorted()
    }

    private static func resolve(_ choice: CustomPlan.Choice, konfession: Kurswahl.Konfession?,
                                plan: Stufenplan) -> Resolution {
        let name = subjectName(choice.subject)
        if let code = choice.code {
            return plan.codes.contains(code) ? .courses([code])
                : .problem(.init(kind: .notInPlan, subject: choice.subject, codes: [code],
                                 message: "\(name): Kurs \(code) steht nicht im Stundenplan"))
        }
        let candidates = candidates(subject: choice.subject, level: choice.level, konfession: konfession, plan: plan)
            .compactMap(CourseCode.init)
        if let parallel = choice.parallel {
            if let exact = candidates.first(where: { $0.number == parallel }) { return .courses([exact.code]) }
            // a subject with a single course has no number in Untis ("esp", "GK")
            if candidates.count == 1 { return .courses([candidates[0].code]) }
            let wanted = SchoolReference.subject(choice.subject)?.stems.first.map { stem in
                (choice.level == .leistungsfach ? stem.prefix(1).uppercased() + stem.dropFirst() : stem) + "\(parallel)"
            } ?? "\(choice.subject)\(parallel)"
            return .problem(.init(kind: .notInPlan, subject: choice.subject, codes: candidates.map(\.code),
                                  message: "\(name): Kurs \(wanted) steht nicht im Stundenplan"))
        }
        if candidates.count == 1 { return .courses([candidates[0].code]) }
        let unnumbered = candidates.filter { $0.number == nil }
        if unnumbered.count == 1 { return .courses([unnumbered[0].code]) }
        if candidates.count > 1 {
            // parallel courses in the very same slots (Basis-Sport s1/s2/s3): the number does not matter here
            let slotSets = candidates.map { c in Set(plan.slots(for: c.code).map { "\($0.day)-\($0.start)-\($0.end)" }) }
            if Set(slotSets).count == 1 { return .courses(candidates.map(\.code)) }
            return .problem(.init(kind: .ambiguous, subject: choice.subject, codes: candidates.map(\.code),
                                  message: "\(name): mehrere Kurse möglich (\(candidates.map(\.code).joined(separator: ", ")))"))
        }
        return .problem(.init(kind: .notInPlan, subject: choice.subject, codes: [],
                              message: "\(name): kein passender Kurs im Stundenplan"))
    }

    static func title(subject: String, level: CustomPlan.Level, codes: [String]) -> String {
        if codes.count > 1 { return "\(subject) (\(codes.joined(separator: " / ")))" }
        let code = codes[0]
        let numbered = CourseCode(code)?.number != nil
        switch level {
        case .leistungsfach: return numbered ? "\(subject) (LF, \(code))" : "\(subject) (LF)"
        case .basisfach: return "\(subject) (\(code))"
        }
    }

    private static func subjectName(_ key: String) -> String { SchoolReference.subject(key)?.name ?? key }

    /// Row order of the Kurswahlprotokoll.
    private static func order(_ key: String) -> Int {
        SchoolReference.subjects.firstIndex { $0.key == key } ?? .max
    }
}

/// A subject matched to course codes of the plan, or why it could not be.
enum Resolution {
    case courses([String])
    case problem(CustomPlan.Issue)
}
