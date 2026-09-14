import Foundation

// MARK: - Schedules

public struct SchedulesData: Codable, Hashable, Sendable {
    public var items: [ScheduleItem]

    public init(items: [ScheduleItem]) { self.items = items }
}

public struct ScheduleItem: Codable, Hashable, Sendable, Identifiable {
    public var id: String { fullUrl }
    public var title: String
    public var url: String
    public var fullUrl: String
    /// "1. Halbjahr" | "2. Halbjahr" | "Unbekannt"
    public var halbjahr: String
    /// "Klassen 5-10" | "J11" | "J12" | "J11/J12" | "Unbekannt"
    public var gradeLevel: String
    public var available: Bool
    public var pdf: PdfRef?
    /// class → REAL 1-based PDF page ("5a"…"10e", "j11", "j12" where present).
    public var classIndex: [String: Int]
    /// Plain text per page (client-side search).
    public var pages: [String]

    /// Grades this PDF covers, discovered from the link title ("… - 5-10" → 5…10,
    /// "… - J11" → [11], "… - J11/12" → [11, 12]); the API's `gradeLevel` as fallback.
    public var grades: [Int] {
        let fromTitle = ScheduleGrades.fromTitle(title)
        if !fromTitle.isEmpty { return fromTitle }
        switch gradeLevel {
        case "Klassen 5-10": return Array(5...10)
        case "J11": return [11]
        case "J12": return [12]
        case "J11/J12": return [11, 12]
        default: return []
        }
    }

    /// Does this PDF contain `cls`? The API's class index is authoritative
    /// (it was built from the PDF's text); grade discovery is the fallback for
    /// a class the index does not list.
    public func covers(_ cls: String) -> Bool {
        if classIndex[cls.lowercased()] != nil { return true }
        guard let grade = ScheduleGrades.gradeOf(cls) else { return false }
        return grades.contains(grade)
    }

    /// The timetables to offer: the newest semester that has published PDFs
    /// (2. Halbjahr over 1. Halbjahr), published items only. When nothing is
    /// published yet, the unpublished set of the preferred semester is
    /// returned so the UI can still explain that the school has not uploaded it.
    public static func preferredGroup(_ items: [ScheduleItem]) -> [ScheduleItem] {
        let published = items.filter { $0.available && $0.pdf != nil }
        for half in ["2. Halbjahr", "1. Halbjahr"] {
            let group = published.filter { $0.halbjahr == half }
            if !group.isEmpty { return group }
        }
        let second = items.filter { $0.halbjahr == "2. Halbjahr" }
        return second.isEmpty ? items.filter { $0.halbjahr == "1. Halbjahr" } : second
    }

    /// 0-based page index for the PDF viewer, or nil when the class is not in this PDF.
    public func pageIndex(forClass cls: String) -> Int? {
        guard let page = classIndex[cls.lowercased()], page >= 1 else { return nil }
        return page - 1
    }
}

// MARK: - Grade discovery (shared by the schedule list and the PDF viewer)

/// Grade discovery from a schedule link title, so a new Jahrgang (J13, a split
/// "J11" / "J12" upload, …) needs no app update.
public enum ScheduleGrades {
    /// Grades named in a schedule link title; ranges ("5-10", "11-12") are expanded,
    /// "J11", "J11/12", "J 13" are read as Jahrgang numbers.
    public static func fromTitle(_ title: String) -> [Int] {
        // only the part after the last " - " names the grades ("Stundenpläne - 2026/2027 - 1.HJ - J11")
        let tail = title.components(separatedBy: " - ").last ?? title
        var grades = Set<Int>()
        for m in tail.matches(of: #/(\d{1,2})\s*-\s*(\d{1,2})/#) {
            if let a = Int(m.1), let b = Int(m.2), a <= b, b - a < 20 { grades.formUnion(a...b) }
        }
        for m in tail.matches(of: #/[Jj]\s*(\d{1,2})(?:\s*/\s*(\d{1,2}))?/#) {
            if let a = Int(m.1) { grades.insert(a) }
            if let second = m.2, let b = Int(second) { grades.insert(b) }
        }
        return grades.sorted()
    }

    /// "10b" → 10, "j11" → 11, "J13" → 13; nil for anything else.
    public static func gradeOf(_ cls: String) -> Int? {
        let lower = cls.lowercased()
        if let m = lower.wholeMatch(of: #/j(\d{1,2})/#) { return Int(m.1) }
        if let m = lower.wholeMatch(of: #/(\d{1,2})[a-e]/#) { return Int(m.1) }
        return nil
    }
}

// MARK: - Class input (shared by every place a class is entered or stored)

/// A class is only accepted when a timetable of the group lists it in its class
/// index, so a typo never becomes the saved class of a card that opens nothing.
public enum ScheduleClasses {
    /// The form class-index keys use: " 10 B " → "10b", "J11" → "j11".
    public static func normalize(_ input: String) -> String {
        String(input.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }).lowercased()
    }

    /// Every class listed by any PDF of the group.
    public static func known(in group: [ScheduleItem]) -> Set<String> {
        Set(group.flatMap(\.classIndex.keys))
    }

    /// The normalised class when the group's index lists it, nil otherwise.
    public static func validate(_ input: String, in group: [ScheduleItem]) -> String? {
        let cls = normalize(input)
        return group.contains(where: { $0.classIndex[cls] != nil }) ? cls : nil
    }
}
