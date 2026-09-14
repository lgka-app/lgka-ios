import Foundation

/// What the custom plan needs from a winprosa "Kurswahlprotokoll": the subjects, and per
/// Halbjahr the weekly hours with the parallel course. Personal data on the sheet (SchNr,
/// SchID, birth date) is never read.
public struct Kurswahl: Codable, Hashable, Sendable {
    /// "Manuel Göring" (the sheet prints "Göring, Manuel").
    public var name: String?
    /// "Abiturjahr: 2028-HJ1" → 2028.
    public var abiturjahr: Int?
    public var konfession: Konfession?
    public var rows: [Row]
    /// The "Summen" row, one value per Halbjahr (nil when unreadable).
    public var sums: [Int?]

    public enum Konfession: String, Codable, Hashable, Sendable {
        case katholisch, evangelisch
    }

    public struct Row: Codable, Hashable, Sendable {
        /// Subject key as printed in the "Fächer" column: "D", "Gk", "Sport".
        public var subject: String
        /// "L", "B", "m", "L/B" (before the choice is made); nil when unreadable.
        public var fachart: String?
        /// One entry per Halbjahr (1. Hj … 4. Hj).
        public var halves: [Cell]

        public init(subject: String, fachart: String?, halves: [Cell]) {
            self.subject = subject
            self.fachart = fachart
            self.halves = halves
        }
    }

    public struct Cell: Codable, Hashable, Sendable {
        /// The recognised text, "5(3)", "2(3).p", "-".
        public var raw: String?
        /// Weekly hours; nil for "-" (not taken) or unreadable.
        public var hours: Int?
        /// Parallel course number in brackets: "5(3)" → 3.
        public var parallel: Int?
        /// The text was found but does not look like a cell value.
        public var unreadable: Bool

        public init(raw: String?, hours: Int?, parallel: Int?, unreadable: Bool) {
            self.raw = raw
            self.hours = hours
            self.parallel = parallel
            self.unreadable = unreadable
        }

        public var taken: Bool { hours != nil }

        public static let missing = Cell(raw: nil, hours: nil, parallel: nil, unreadable: true)
    }

    public init(name: String?, abiturjahr: Int?, konfession: Konfession?, rows: [Row], sums: [Int?]) {
        self.name = name
        self.abiturjahr = abiturjahr
        self.konfession = konfession
        self.rows = rows
        self.sums = sums
    }

    /// Which of the four Halbjahr columns belongs to a plan: J11 → 0/1, J12 → 2/3.
    public static func halfIndex(grade: Int, halbjahr: String) -> Int {
        (grade >= 12 ? 2 : 0) + (halbjahr.hasPrefix("2") ? 1 : 0)
    }

    /// The Jahrgang the sheet belongs to in a school year: Abitur 2028 in 2026-2027 → 11.
    public func grade(inSchuljahr schuljahr: String) -> Int? {
        guard let abiturjahr, let start = Int(schuljahr.prefix(4)) else { return nil }
        let grade = 13 - (abiturjahr - start - 1) - 1
        return (11...12).contains(grade) ? grade : nil
    }
}

/// Reads a Kurswahlprotokoll from text recognised on a photo (boxes 0…1, origin top-left).
/// Takes the boxes of several recognition passes at once; for every cell the most plausible
/// reading wins.
///
/// Anchors: the subject abbreviations form the left column and give the rows; the "Summen"
/// row gives the x of the four Halbjahr columns (its first four numbers). A tilt of the photo
/// is taken out with the slope of that row.
public enum KurswahlParser {
    public enum Failure: Error, Equatable {
        /// No subject column was found: not a Kurswahlprotokoll, or the photo is unreadable.
        case noSubjects
        /// The Halbjahr columns could not be located.
        case noColumns
    }

    public static func parse(_ boxes: [TextBox]) throws -> Kurswahl {
        let words = boxes.flatMap { $0.words() }.map { normalised($0) }
        let lines = boxes.map { normalised($0) }

        // subject column: the x where most subject abbreviations line up
        let keys = SchoolReference.subjects.map(\.key)
        let subjectBoxes = words.filter { w in keys.contains(where: { $0.caseInsensitiveCompare(w.text) == .orderedSame }) }
        guard let columnX = densestX(subjectBoxes.map(\.midX), window: 0.03) else { throw Failure.noSubjects }
        var rowsFound: [TextBox] = []
        for b in subjectBoxes.filter({ abs($0.midX - columnX) < 0.04 }).sorted(by: { $0.midY < $1.midY }) {
            // the same subject from a second pass is one row
            if let last = rowsFound.last, abs(last.midY - b.midY) < 0.006 {
                if (b.confidence ?? 0) > (last.confidence ?? 0) { rowsFound[rowsFound.count - 1] = b }
                continue
            }
            rowsFound.append(b)
        }
        guard rowsFound.count >= 5 else { throw Failure.noSubjects }
        let pitch = rowsFound.map(\.midY).adjacentDifferences.median ?? 0.018

        // Halbjahr columns from the "Summen" row
        let summen = lines.first(where: { $0.text.lowercased().hasPrefix("summen") })
        var columns: [Double] = []
        var slope = 0.0
        var sums: [Int?] = [nil, nil, nil, nil]
        if let summen {
            let numbers = words.filter { w in
                w.midX > columnX + 0.12 && abs(w.midY - summen.midY) < pitch * 1.2 && w.text.wholeMatch(of: #/\d{2}/#) != nil
            }
            .sorted { $0.midX < $1.midX }
            let deduped = numbers.reduce(into: [TextBox]()) { acc, w in
                if let last = acc.last, abs(last.midX - w.midX) < 0.02 { return }
                acc.append(w)
            }
            if deduped.count >= 4 {
                let first4 = Array(deduped.prefix(4))
                columns = first4.map(\.midX)
                sums = first4.map { Int($0.text) }
                let dx = first4[3].midX - summen.midX
                if dx > 0.1 { slope = (first4[3].midY - summen.midY) / dx }
            }
        }
        if columns.isEmpty {
            // fallback: the bracketed values "5(3)" sit in the first Halbjahr column
            let bracketed = words.filter { parseCell($0.text).parallel != nil }.map(\.midX)
            guard let first = densestX(bracketed, window: 0.02) else { throw Failure.noColumns }
            columns = (0..<4).map { first + Double($0) * 0.062 }
        }
        let spacing = columns.map { $0 }.adjacentDifferences.median ?? 0.062
        let fachartX = columns[0] - spacing * 2
        let lowest = rowsFound.last?.midY ?? 1

        var rows: [Kurswahl.Row] = []
        for subject in rowsFound {
            let key = keys.first { $0.caseInsensitiveCompare(subject.text) == .orderedSame } ?? subject.text
            // expected y of this row at a given x, following the tilt
            func onRow(_ w: TextBox) -> Bool {
                abs(w.midY - (subject.midY + slope * (w.midX - subject.midX))) < pitch * 0.42
            }
            let rowWords = words.filter { $0.midX > columnX + 0.03 && onRow($0) && $0.midY < lowest + pitch }
            var halves: [Kurswahl.Cell] = []
            for cx in columns {
                let candidates = rowWords.filter { abs($0.midX - cx) < spacing * 0.42 }
                    .map { (box: $0, cell: parseCell($0.text)) }
                let best = candidates.max { a, b in score(a.cell, a.box) < score(b.cell, b.box) }
                halves.append(best?.cell ?? .missing)
            }
            let fachart = rowWords.filter { abs($0.midX - fachartX) < spacing * 0.6 }
                .map(\.text).first { ["L", "B", "m", "L/B"].contains($0) }
            rows.append(.init(subject: key, fachart: fachart, halves: halves))
        }

        let name = lines.first { line in
            line.midY < (rowsFound.first?.midY ?? 1) - 0.1
                && line.text.wholeMatch(of: #/[A-ZÄÖÜ][\p{L}\-]+(?: [\p{L}\-]+)*,\s*[A-ZÄÖÜ][\p{L}\- ]+/#) != nil
                && !line.text.hasPrefix("Name")
                && !line.text.hasPrefix("Datum")
        }
        .map { line -> String in
            let parts = line.text.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            return parts.count == 2 ? "\(parts[1]) \(parts[0])" : line.text
        }
        let abiturjahr = lines.compactMap { $0.text.firstMatch(of: #/Abiturjahr:?\s*(\d{4})/#).flatMap { Int($0.1) } }.first
        let konfession: Kurswahl.Konfession? =
            lines.contains(where: { $0.text.lowercased().contains("katholisch") }) ? .katholisch
            : lines.contains(where: { $0.text.lowercased().contains("evangelisch") }) ? .evangelisch : nil

        return Kurswahl(name: name, abiturjahr: abiturjahr, konfession: konfession, rows: rows, sums: sums)
    }

    /// "5(3)" → 5 hours, course 3; "2(3).p" → 2, course 3; "2.s" → 2; "-" → not taken.
    public static func parseCell(_ text: String) -> Kurswahl.Cell {
        var t = normalised(TextBox(text: text, x: 0, y: 0, width: 0, height: 0)).text.replacingOccurrences(of: " ", with: "")
        for (from, to) in [("[", "("), ("{", "("), ("]", ")"), ("}", ")"), (",", "."), ("S.", "5.")] {
            t = t.replacingOccurrences(of: from, with: to)
        }
        if t.isEmpty { return .missing }
        if t.allSatisfy({ "-–—_.".contains($0) }) {
            return .init(raw: text, hours: nil, parallel: nil, unreadable: false)
        }
        if let m = t.wholeMatch(of: #/(\d)(?:\((\d)\)?)?(?:\.?([psPS]))?/#) {
            return .init(raw: text, hours: Int(m.1), parallel: m.2.flatMap { Int($0) }, unreadable: false)
        }
        // specks and table lines read as "..E" are not a value; only text with a digit is worth asking about
        let unreadable = t.contains(where: \.isNumber)
        return .init(raw: unreadable ? text : nil, hours: nil, parallel: nil, unreadable: unreadable)
    }

    /// Prefers readable values, then bracketed ones (the most specific), then confidence.
    private static func score(_ cell: Kurswahl.Cell, _ box: TextBox) -> Double {
        (cell.unreadable ? 0 : 10) + (cell.parallel != nil ? 2 : 0) + (box.confidence ?? 0.5)
    }

    /// Text recognition reads some Latin letters as look-alike Cyrillic or Greek ones.
    private static func normalised(_ box: TextBox) -> TextBox {
        let map: [Character: Character] = [
            "Р": "P", "р": "p", "С": "C", "с": "c", "О": "O", "о": "o", "Е": "E", "е": "e",
            "Ѕ": "S", "ѕ": "s", "Н": "H", "К": "K", "М": "M", "Т": "T", "В": "B", "А": "A", "а": "a",
            "Ο": "O", "ο": "o", "Ι": "I", "Β": "B",
        ]
        var copy = box
        copy.text = String(box.text.map { map[$0] ?? $0 }).trimmingCharacters(in: .whitespaces)
        return copy
    }

    /// The centre of the densest cluster of x values.
    private static func densestX(_ xs: [Double], window: Double) -> Double? {
        guard !xs.isEmpty else { return nil }
        let best = xs.max { a, b in
            xs.filter { abs($0 - a) < window }.count < xs.filter { abs($0 - b) < window }.count
        }
        guard let best else { return nil }
        return xs.filter { abs($0 - best) < window }.median
    }
}

extension Array where Element == Double {
    /// Differences between neighbours: [1, 3, 6] → [2, 3].
    var adjacentDifferences: [Double] {
        count < 2 ? [] : (1..<count).map { self[$0] - self[$0 - 1] }
    }
}
