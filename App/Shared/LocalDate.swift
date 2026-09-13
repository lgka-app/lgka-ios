import Foundation

/// Calendar-day helpers replacing ad-hoc DateFormatters in view bodies.
enum LocalDate {
    static var calendar: Calendar { Calendar.current }

    /// "yyyy-MM-dd" -> Date at local midnight, nil if malformed.
    static func parse(_ iso: String) -> Date? {
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: d))
    }

    static func isToday(_ iso: String) -> Bool {
        guard let date = parse(iso) else { return false }
        return calendar.isDateInToday(date)
    }
}
