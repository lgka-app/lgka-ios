import Foundation

// MARK: - Substitutions

public struct SubstitutionsData: Codable, Hashable, Sendable {
    public var today: DayPlan?
    public var tomorrow: DayPlan?

    public init(today: DayPlan? = nil, tomorrow: DayPlan? = nil) {
        self.today = today
        self.tomorrow = tomorrow
    }
}

public struct DayPlan: Codable, Hashable, Sendable {
    /// Upstream file name, e.g. "v_schueler_heute.pdf".
    public var source: String
    public var pdf: PdfRef
    public var sourceLastModified: String?
    public var meta: SubstitutionMeta
    public var plan: SubstitutionPlan
    /// Plain text per page (client-side search).
    public var pages: [String]

    /// The app's display rule (SubstitutionState.canDisplay parity).
    public var canDisplay: Bool {
        !plan.isEmpty && meta.weekday != "weekend" && !meta.weekday.isEmpty && !meta.date.isEmpty
    }
}

public struct SubstitutionMeta: Codable, Hashable, Sendable {
    /// German weekday, or "weekend" for the empty export.
    public var weekday: String
    /// DD.MM.YYYY
    public var date: String
    /// Generation timestamp as printed in the PDF, e.g. "11.9.2026 8:56".
    public var lastUpdated: String
}

public struct SubstitutionPlan: Codable, Hashable, Sendable {
    public var school: String?
    public var address: String?
    public var schoolYear: String?
    public var untisVersion: String?
    public var generatedAt: String?
    public var planDate: String?
    public var weekday: String?
    public var isEmpty: Bool
    public var announcements: [String]
    public var absentTeachers: [String]
    public var absentClasses: [String]
    public var blockedRooms: [String]
    public var entries: [SubstitutionEntry]
    public var footer: SubstitutionFooter?
    public var pageCount: Int

    /// Entries affecting `className` ("6a" matches cells "6a", "6ab", "5c, 6a").
    public func entries(forClass className: String) -> [SubstitutionEntry] {
        let lc = className.lowercased()
        return entries.filter { $0.classes.contains { $0.lowercased() == lc } }
    }
}

public struct SubstitutionEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: String {
        [type, period, classesRaw, substitute, subject, room, originalSubject, originalTeacher, originalRoom, note]
            .map { $0 ?? "" }.joined(separator: "|") + "|\(page)"
    }
    public var type: String?
    public var period: String?
    public var classes: [String]
    public var classesRaw: String?
    public var substitute: String?
    public var subject: String?
    public var room: String?
    public var originalSubject: String?
    public var originalTeacher: String?
    public var originalRoom: String?
    public var note: String?
    /// 0-based page the entry starts on.
    public var page: Int
}

public struct SubstitutionFooter: Codable, Hashable, Sendable {
    public var untisPeriod: Int?
    public var date: String?
    public var calendarWeek: Int?
    public var schoolYearShort: String?
}
