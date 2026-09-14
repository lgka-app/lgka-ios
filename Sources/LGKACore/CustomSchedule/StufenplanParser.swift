import Foundation

/// Every course slot of an Untis "Stufenplan" (the one-page J11 / J12 grid the school publishes).
public struct Stufenplan: Codable, Hashable, Sendable {
    /// "J11", "J12".
    public var stufe: String
    /// "2026-2027".
    public var schuljahr: String?
    /// Untis export time, "7.9.2026 14:39".
    public var stand: String?
    public var slots: [Slot]

    public struct Slot: Codable, Hashable, Sendable {
        /// 0 = Montag … 4 = Freitag.
        public var day: Int
        public var start: Int
        public var end: Int
        /// Untis course code without the leading separator dot: "M3", "d3", "kR1", "GK".
        public var code: String
        public var teacher: String?
        public var room: String?

        public init(day: Int, start: Int, end: Int, code: String, teacher: String?, room: String?) {
            self.day = day
            self.start = start
            self.end = end
            self.code = code
            self.teacher = teacher
            self.room = room
        }

        public var hours: Int { end - start + 1 }
    }

    public init(stufe: String, schuljahr: String?, stand: String?, slots: [Slot]) {
        self.stufe = stufe
        self.schuljahr = schuljahr
        self.stand = stand
        self.slots = slots
    }

    /// Every course code in the plan.
    public var codes: Set<String> { Set(slots.map(\.code)) }

    public func slots(for code: String) -> [Slot] { slots.filter { $0.code == code } }

    /// 11 for "J11".
    public var grade: Int? { Int(stufe.drop(while: { !$0.isNumber })) }
}

/// Reads an Untis Stufenplan from the positioned words of its PDF page. No OCR: the PDF
/// carries real text, only its reading order is useless, so the grid is rebuilt from positions.
///
/// Layout: day names head five columns, period numbers run down the left margin, and every
/// cell is a block of a course-code line, a teacher line and an (italic) room line, the three
/// aligned column by column. A block centred on a period label is a single period, a block
/// centred between two labels a double period.
public enum StufenplanParser {
    public enum Failure: Error, Equatable {
        case noDayHeader
        case noPeriodLabels
    }

    public static let dayNames = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"]

    /// Rooms when the PDF does not say which words are italic.
    private static var roomPattern: Regex<(Substring, Substring, Substring?)> { #/^(\d{3}|NWT\d*|BIO[A-Z]*|CHHS|PHHS|MUSIK|BK(OG|UG)|WB\d|CBH|FrEb|Less|AULA|Aula)$/# }

    public static func parse(_ words: [TextBox]) throws -> Stufenplan {
        let headers = dayNames.compactMap { name in words.first(where: { $0.text == name }) }
        guard headers.count == dayNames.count else { throw Failure.noDayHeader }
        let dayX = headers.map(\.midX)
        let headerBottom = headers.map(\.maxY).max() ?? 0
        let columnWidth = (dayX[4] - dayX[0]) / 4
        let gridLeft = dayX[0] - columnWidth / 2

        var labels: [Int: Double] = [:]
        for w in words where w.midX < gridLeft && w.y > headerBottom {
            if let n = Int(w.text), (1...15).contains(n), labels[n] == nil { labels[n] = w.midY }
        }
        guard labels.count >= 2 else { throw Failure.noPeriodLabels }
        var labelGaps: [Double] = []
        for p in labels.keys.sorted() {
            if let a = labels[p], let b = labels[p + 1] { labelGaps.append(b - a) }
        }
        let rowHeight = labelGaps.median ?? 38

        var slots: [Stufenplan.Slot] = []
        let grid = words.filter { $0.y > headerBottom + 2 && $0.midX > gridLeft }
        for day in 0..<dayNames.count {
            let inColumn = grid.filter { w in
                dayX.indices.min(by: { abs(dayX[$0] - w.midX) < abs(dayX[$1] - w.midX) }) == day
            }
            let lines = Self.lines(inColumn, tolerance: rowHeight * 0.06)
            var i = 0
            while i < lines.count {
                let code = lines[i]
                var teacher: [TextBox] = []
                var room: [TextBox] = []
                var used = 1
                if i + 1 < lines.count, lines[i + 1].y - code.y < rowHeight * 0.6, !isRoomLine(lines[i + 1].words) {
                    teacher = lines[i + 1].words
                    used = 2
                    if i + 2 < lines.count, lines[i + 2].y - lines[i + 1].y < rowHeight * 0.6, isRoomLine(lines[i + 2].words) {
                        room = lines[i + 2].words
                        used = 3
                    }
                }
                let centre = teacher.first?.midY ?? code.y
                let (start, end) = span(centredAt: centre, labels: labels)
                for c in code.words {
                    let text = c.text.hasPrefix(".") ? String(c.text.dropFirst()) : c.text
                    guard !text.isEmpty else { continue }
                    slots.append(.init(day: day, start: start, end: end, code: text,
                                       teacher: aligned(teacher, with: c, within: 12)?.text,
                                       room: aligned(room, with: c, within: 14)?.text))
                }
                i += used
            }
        }

        let top = words.filter { $0.y < headerBottom - 5 }
        let stufe = top.first(where: { $0.text.wholeMatch(of: #/J\d{2}/#) != nil })?.text ?? "J?"
        let schuljahr = top.first(where: { $0.text.wholeMatch(of: #/\d{4}-\d{4}/#) != nil })?.text
        var stand: String?
        if let date = top.first(where: { $0.text.wholeMatch(of: #/\d{1,2}\.\d{1,2}\.\d{4}/#) != nil }) {
            let time = top.first(where: { abs($0.midY - date.midY) < 3 && $0.x > date.x && $0.text.wholeMatch(of: #/\d{1,2}:\d{2}/#) != nil })
            stand = [date.text, time?.text].compactMap { $0 }.joined(separator: " ")
        }
        let ordered = slots.sorted { a, b in
            if a.day != b.day { return a.day < b.day }
            if a.start != b.start { return a.start < b.start }
            return a.code < b.code
        }
        return Stufenplan(stufe: stufe, schuljahr: schuljahr, stand: stand, slots: ordered)
    }

    private struct Line {
        var y: Double
        var words: [TextBox]
    }

    /// Words grouped into lines (by vertical centre), top to bottom, each line left to right.
    private static func lines(_ words: [TextBox], tolerance: Double) -> [Line] {
        var lines: [Line] = []
        for w in words.sorted(by: { $0.midY < $1.midY }) {
            if let last = lines.indices.last, abs(lines[last].y - w.midY) <= tolerance {
                lines[last].words.append(w)
            } else {
                lines.append(Line(y: w.midY, words: [w]))
            }
        }
        return lines.map { Line(y: $0.y, words: $0.words.sorted { $0.x < $1.x }) }
    }

    private static func isRoomLine(_ words: [TextBox]) -> Bool {
        if words.allSatisfy({ $0.italic != nil }) { return words.allSatisfy { $0.italic == true } }
        return words.allSatisfy { $0.text.wholeMatch(of: roomPattern) != nil }
    }

    private static func span(centredAt y: Double, labels: [Int: Double]) -> (Int, Int) {
        var best = (0, 0)
        var distance = Double.infinity
        for (p, ly) in labels {
            if abs(ly - y) < distance { distance = abs(ly - y); best = (p, p) }
            if let next = labels[p + 1], abs((ly + next) / 2 - y) < distance {
                distance = abs((ly + next) / 2 - y)
                best = (p, p + 1)
            }
        }
        return best
    }

    private static func aligned(_ line: [TextBox], with word: TextBox, within tolerance: Double) -> TextBox? {
        guard let nearest = line.min(by: { abs($0.midX - word.midX) < abs($1.midX - word.midX) }),
              abs(nearest.midX - word.midX) < tolerance else { return nil }
        return nearest
    }
}
