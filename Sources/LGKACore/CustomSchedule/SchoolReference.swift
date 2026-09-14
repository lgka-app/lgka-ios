import Foundation

/// Fixed facts of the Lessing-Gymnasium the custom plan needs: Läuteordnung, subjects of the
/// Kurswahlprotokoll with their Untis course stems, and the teacher codes of the Kollegium.
public enum SchoolReference {
    // MARK: Läuteordnung (Schulordnung 2025, valid from SJ 2025/26)

    public struct Period: Codable, Hashable, Sendable {
        public var number: Int
        public var start: String
        public var end: String
    }

    public struct Break: Codable, Hashable, Sendable {
        /// The break follows this period.
        public var after: Int
        public var start: String
        public var end: String
    }

    /// The school website still shows an older grid; this is the valid one.
    public static let periods: [Period] = [
        .init(number: 1, start: "7:45", end: "8:30"), .init(number: 2, start: "8:35", end: "9:20"),
        .init(number: 3, start: "9:35", end: "10:20"), .init(number: 4, start: "10:25", end: "11:10"),
        .init(number: 5, start: "11:30", end: "12:15"), .init(number: 6, start: "12:20", end: "13:05"),
        .init(number: 7, start: "13:10", end: "13:55"), .init(number: 8, start: "14:00", end: "14:45"),
        .init(number: 9, start: "14:50", end: "15:35"), .init(number: 10, start: "15:50", end: "16:35"),
        .init(number: 11, start: "16:35", end: "17:20"),
    ]

    public static let breaks: [Break] = [
        .init(after: 2, start: "9:20", end: "9:35"),
        .init(after: 4, start: "11:10", end: "11:30"),
        .init(after: 9, start: "15:35", end: "15:50"),
    ]

    /// Double-period blocks 1–2, 3–4, 5–6, 10–11; 7, 8, 9 are single periods.
    public static let blockStarts: Set<Int> = [1, 3, 5, 7, 8, 9, 10]

    public static let laeuteordnungSource = "Läuteordnung ab SJ 2025/26 (Schulordnung, Stand 2025)"

    // MARK: Subjects

    public struct Subject: Sendable, Hashable {
        /// The abbreviation in the Kurswahlprotokoll's "Fächer" column: "D", "Gk", "Sport".
        public var key: String
        public var name: String
        /// Lower-cased letter part of the Untis course codes: "m" matches "M3" and "m1".
        public var stems: [String]
    }

    public static let subjects: [Subject] = [
        .init(key: "D", name: "Deutsch", stems: ["d"]),
        .init(key: "E", name: "Englisch", stems: ["e"]),
        .init(key: "F", name: "Französisch", stems: ["f"]),
        .init(key: "Sp", name: "Spanisch", stems: ["esp", "sp"]),
        .init(key: "L", name: "Latein", stems: ["l"]),
        .init(key: "I", name: "Italienisch", stems: ["i"]),
        .init(key: "BK", name: "Bildende Kunst", stems: ["bk"]),
        .init(key: "Mu", name: "Musik", stems: ["mus", "mu"]),
        .init(key: "G", name: "Geschichte", stems: ["g"]),
        .init(key: "Gk", name: "Gemeinschaftskunde", stems: ["gk"]),
        .init(key: "Geo", name: "Geographie", stems: ["geo"]),
        .init(key: "WBS", name: "Wirtschaft", stems: ["wbs", "wi"]),
        .init(key: "Rel", name: "Religion", stems: ["kr", "er"]),
        .init(key: "Eth", name: "Ethik", stems: ["eth"]),
        .init(key: "Phil", name: "Philosophie", stems: ["phil"]),
        .init(key: "M", name: "Mathematik", stems: ["m"]),
        .init(key: "Bio", name: "Biologie", stems: ["bio"]),
        .init(key: "Ph", name: "Physik", stems: ["ph"]),
        .init(key: "Ch", name: "Chemie", stems: ["ch"]),
        .init(key: "NwT", name: "NwT", stems: ["nwt"]),
        .init(key: "Inf", name: "Informatik", stems: ["inf"]),
        .init(key: "Sport", name: "Sport", stems: ["s", "spo"]),
        .init(key: "Psy", name: "Psychologie", stems: ["psy"]),
        .init(key: "Ast", name: "Astronomie", stems: ["ast"]),
        .init(key: "LTh", name: "Literatur und Theater", stems: ["lth"]),
    ]

    public static func subject(_ key: String) -> Subject? {
        subjects.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }
    }

    /// Religion is printed as "kath. Religion" / "ev. Religion" depending on the course stem.
    public static func subjectName(key: String, code: String) -> String {
        if key == "Rel" {
            let stem = CourseCode(code)?.stem
            if stem == "kr" { return "kath. Religion" }
            if stem == "er" { return "ev. Religion" }
        }
        return subject(key)?.name ?? key
    }

    // MARK: Kollegium

    /// "Dr. Daniel Roth" from the synced staff list (api.lgka.app/v1/kollegium); nil for a code it
    /// doesn't know yet, which is then shown as it is printed in the timetable.
    public static func teacherName(_ code: String) -> String? { TeacherDirectory.shared.name(code) }

    /// "Roth", for cells naming several teachers; the code for one the staff list doesn't know.
    public static func lastName(_ code: String) -> String { TeacherDirectory.shared.lastName(code) }
}

/// An Untis course code split into its parts: "M3" → stem "m", number 3, leistungsfach.
public struct CourseCode: Hashable, Sendable {
    public var code: String
    /// Lower-cased letters: "m", "kr", "esp".
    public var stem: String
    public var number: Int?
    /// Untis writes Leistungsfach courses with a capital first letter ("M3", "Esp", "S1").
    public var capitalised: Bool

    public init?(_ code: String) {
        guard let m = code.wholeMatch(of: #/([A-Za-zÄÖÜäöü]+)(\d*)/#) else { return nil }
        self.code = code
        stem = String(m.1).lowercased()
        number = Int(m.2)
        capitalised = m.1.first?.isUppercase ?? false
    }
}
