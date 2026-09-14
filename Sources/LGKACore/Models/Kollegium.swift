import Foundation

// MARK: - Kollegium

/// `/v1/kollegium`: the staff list of the school website, refreshed by the API once a day.
public struct KollegiumData: Codable, Hashable, Sendable {
    /// When the list last changed.
    public var updatedAt: String?
    public var source: String?
    /// "2024/2025" as stated on the page; nil when it states none.
    public var schoolYear: String?
    public var staff: [Staff]

    public struct Staff: Codable, Hashable, Sendable {
        /// Untis code as printed in the timetables ("Ro").
        public var code: String
        public var lastName: String
        public var firstName: String?
        /// "Dr."
        public var title: String?
        /// "Dr. Daniel Roth"
        public var displayName: String
        public var subjects: [String]
        /// schulleitung, stellvertretendeSchulleitung, abteilungsleitung, lehrkraft, referendar, sonstige
        public var role: String
        /// The page's heading, "Abteilungsleiter".
        public var roleLabel: String?

        public init(code: String, lastName: String, firstName: String?, title: String?, displayName: String,
                    subjects: [String], role: String, roleLabel: String?) {
            self.code = code
            self.lastName = lastName
            self.firstName = firstName
            self.title = title
            self.displayName = displayName
            self.subjects = subjects
            self.role = role
            self.roleLabel = roleLabel
        }
    }

    public init(updatedAt: String? = nil, source: String? = nil, schoolYear: String? = nil, staff: [Staff]) {
        self.updatedAt = updatedAt
        self.source = source
        self.schoolYear = schoolYear
        self.staff = staff
    }
}

/// The teachers the app knows by their Untis code, filled from the synced staff list. A code the
/// list doesn't contain (a new teacher before the next daily refresh) is shown as the code itself.
public final class TeacherDirectory: @unchecked Sendable {
    public static let shared = TeacherDirectory()

    private let lock = NSLock()
    private var byCode: [String: KollegiumData.Staff] = [:]

    public init(staff: [KollegiumData.Staff] = []) {
        update(staff)
    }

    public func update(_ staff: [KollegiumData.Staff]) {
        let table = Dictionary(staff.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
        lock.withLock { byCode = table }
    }

    public func staff(_ code: String) -> KollegiumData.Staff? {
        lock.withLock { byCode[code] }
    }

    /// "Dr. Daniel Roth", or nil for an unknown code.
    public func name(_ code: String) -> String? { staff(code)?.displayName }

    /// "Roth", for cells naming several teachers; the code for an unknown one.
    public func lastName(_ code: String) -> String { staff(code)?.lastName ?? code }
}
