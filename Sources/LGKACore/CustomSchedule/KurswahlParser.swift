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
        /// Subject key as printed in the "Fächer" column: "D", "Gk", "Sport"; "?" for a row whose
        /// subject could not be read.
        public var subject: String
        /// "L", "B", "m", "L/B" (before the choice is made); nil when unreadable.
        public var fachart: String?
        /// One entry per Halbjahr (1. Hj … 4. Hj).
        public var halves: [Cell]
        /// What was read in the subject column of a "?" row, if anything.
        public var label: String?

        public init(subject: String, fachart: String?, halves: [Cell], label: String? = nil) {
            self.subject = subject
            self.fachart = fachart
            self.halves = halves
            self.label = label
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
        let grade = 13 - (abiturjahr - start)
        return (11...12).contains(grade) ? grade : nil
    }
}

/// Reads a Kurswahlprotokoll from text recognised on a photo (boxes 0…1, origin top-left).
/// Takes the boxes of several recognition passes at once; for every cell the most plausible
/// reading wins.
///
/// Anchors: the subject abbreviations form the left column and give the rows, with the regular
/// row pitch filling in rows whose subject was not recognised. The "Summen" row gives the x of
/// the four Halbjahr columns (its first four numbers, on a line that may be tilted); the tilt of
/// the photo is taken out of every row.
public enum KurswahlParser {
    public enum Failure: Error, Equatable {
        /// No subject column was found: not a Kurswahlprotokoll, or the photo is unreadable.
        case noSubjects
        /// The Halbjahr columns could not be located.
        case noColumns
    }

    /// Column spacing ÷ row pitch of the printed form, in pixels.
    private static let columnToRowRatio = 2.54

    /// - Parameter aspect: image height ÷ width, to relate row and column distances.
    public static func parse(_ boxes: [TextBox], aspect: Double = 4.0 / 3.0) throws -> Kurswahl {
        let words = boxes.flatMap { $0.words() }.map { normalised($0) }
        let lines = boxes.map { normalised($0) }

        // subject column: the x where most subject abbreviations line up
        let subjectBoxes = words.filter { subjectKey($0.text) != nil }
        guard let columnX = densestX(subjectBoxes.map(\.midX), window: 0.03) else { throw Failure.noSubjects }
        var found: [(key: String, box: TextBox)] = []
        for b in subjectBoxes.filter({ abs($0.midX - columnX) < 0.04 }).sorted(by: { $0.midY < $1.midY }) {
            guard let key = subjectKey(b.text) else { continue }
            // the same subject from a second pass is one row
            if let last = found.last, abs(last.box.midY - b.midY) < 0.006 {
                if (b.confidence ?? 0) > (last.box.confidence ?? 0) { found[found.count - 1] = (key, b) }
                continue
            }
            found.append((key, b))
        }
        guard found.count >= 5 else { throw Failure.noSubjects }
        let diffs = found.map(\.box.midY).adjacentDifferences
        var pitch = diffs.median ?? 0.018
        if let regular = diffs.filter({ $0 < pitch * 1.5 }).median { pitch = regular }

        // rows: every recognised subject, plus rows in gaps of the regular pitch (a subject the
        // recognition missed, or an empty "--" row) and between the table header and the first row
        var anchors: [(key: String?, y: Double)] = found.map { ($0.key, $0.box.midY) }
        var gaps: [Double] = []
        for (a, b) in zip(anchors, anchors.dropFirst()) {
            let n = Int(((b.y - a.y) / pitch).rounded())
            if n >= 2 { for j in 1..<n { gaps.append(a.y + (b.y - a.y) * Double(j) / Double(n)) } }
        }
        let headerTexts = ["pro kurs", "fachart", "fächer"]
        if let first = anchors.first,
           let header = lines.filter({ line in headerTexts.contains { line.text.lowercased().contains($0) } && line.midY < first.y }).map(\.midY).max() {
            let n = Int(((first.y - header) / pitch).rounded())
            if n >= 2 { for j in 1..<n { gaps.append(first.y - Double(j) * pitch) } }
        }
        anchors += gaps.map { (nil, $0) }
        anchors.sort { $0.y < $1.y }

        // slope of the photo: from the "Summen" row, else from the bracketed values next to their subjects
        let summen = lines.first(where: { $0.text.lowercased().hasPrefix("summen") })
            ?? words.first(where: { $0.text.lowercased().hasPrefix("summen") })
        var columns: [Double] = []
        var sums: [Int?] = [nil, nil, nil, nil]
        var slope = 0.0
        // "Summen" itself is not always recognised; then the numbers under the table stand in for it
        let lastRowY = found.last?.box.midY ?? 0
        let sumAnchors = summen.map { [$0] } ?? words.filter { w in
            w.midY > lastRowY && w.midY < lastRowY + pitch * 8 && w.midX > columnX + 0.12
                && w.text.wholeMatch(of: #/\d{2}\.?/#) != nil
        }
        .sorted { $0.midX < $1.midX }
        let sumLine = sumAnchors.lazy.compactMap { sumRow(words, anchor: $0, columnX: columnX, pitch: pitch) }.first
        if let row = sumLine {
            columns = row.boxes.map(\.midX)
            sums = row.boxes.map { Int($0.text.filter(\.isNumber)) }
            slope = row.slope
        } else {
            slope = bracketSlope(words, rows: found.map(\.box), pitch: pitch)
        }
        if columns.isEmpty {
            // fallback: the bracketed values "5(3)" sit in the first Halbjahr column
            let bracketed = words.filter { parseCell($0.text).parallel != nil }.map(\.midX)
            guard let first = densestX(bracketed, window: 0.02) else { throw Failure.noColumns }
            let spacing = columnToRowRatio * pitch * aspect
            columns = (0..<4).map { first + Double($0) * spacing }
        }
        let spacing = columns.adjacentDifferences.median ?? columnToRowRatio * pitch * aspect
        let fachartX = columns[0] - spacing * 2
        let lowest = summen?.midY ?? sumLine?.boxes.first?.midY ?? (lastRowY + pitch)

        var rows: [Kurswahl.Row] = []
        for anchor in anchors where anchor.y < lowest - pitch * 0.5 {
            // expected y of this row at a given x, following the tilt
            func onRow(_ w: TextBox) -> Bool {
                abs(w.midY - (anchor.y + slope * (w.midX - columnX))) < pitch * 0.42
            }
            let rowWords = words.filter { onRow($0) }
            var halves: [Kurswahl.Cell] = []
            for cx in columns {
                let candidates = rowWords.filter { abs($0.midX - cx) < spacing * 0.42 }
                    .map { (box: $0, cell: parseCell($0.text)) }
                let best = candidates.max { a, b in score(a.cell, a.box) < score(b.cell, b.box) }
                halves.append(best?.cell ?? .missing)
            }
            let fachart = rowWords.filter { abs($0.midX - fachartX) < spacing * 0.6 }
                .map(\.text).first { ["L", "B", "m", "L/B"].contains($0) }
            if let key = anchor.key {
                rows.append(.init(subject: key, fachart: fachart, halves: halves))
            } else {
                // a gap row: only worth keeping when something is taken in it
                guard halves.contains(where: \.taken) else { continue }
                let label = rowWords.filter { abs($0.midX - columnX) < 0.04 }.map(\.text).first
                rows.append(.init(subject: label.flatMap(misreadSubject) ?? "?", fachart: fachart, halves: halves, label: label))
            }
        }

        let name = lines.first { line in
            line.midY < (found.first?.box.midY ?? 1) - 0.1
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

    /// The four Halbjahr sums: two-digit numbers on one straight line through `anchor` ("Summen",
    /// or the first sum). The photo may be tilted, so the line is searched, not assumed horizontal.
    private static func sumRow(_ words: [TextBox], anchor: TextBox, columnX: Double, pitch: Double) -> (boxes: [TextBox], slope: Double)? {
        let numbers = words.filter { w in
            w.midX > columnX + 0.12 && abs(w.midY - anchor.midY) < pitch * 4 && w.text.wholeMatch(of: #/\d{2}\.?/#) != nil
        }
        let summen = anchor
        var best: (boxes: [TextBox], slope: Double)?
        for candidate in numbers {
            let dx = candidate.midX - summen.midX
            guard dx > 0.05 else { continue }
            let slope = (candidate.midY - summen.midY) / dx
            guard abs(slope) < 0.2 else { continue }
            let onLine = numbers
                .filter { $0.midX >= summen.midX - 0.01 && abs($0.midY - (summen.midY + slope * ($0.midX - summen.midX))) < pitch * 0.5 }
                .sorted { $0.midX < $1.midX }
                .reduce(into: [TextBox]()) { acc, w in
                    if let last = acc.last, abs(last.midX - w.midX) < 0.02 { return }
                    acc.append(w)
                }
            if onLine.count >= 4, onLine.count > (best?.boxes.count ?? 0) {
                let first4 = Array(onLine.prefix(4))
                let reference = first4[0].midX - summen.midX > 0.05 ? summen : first4[0]
                let fitted = (first4[3].midY - reference.midY) / (first4[3].midX - reference.midX)
                best = (first4, fitted)
            }
        }
        return best
    }

    /// Tilt from bracketed values ("5(3)") and the subject on their row.
    private static func bracketSlope(_ words: [TextBox], rows: [TextBox], pitch: Double) -> Double {
        var slopes: [Double] = []
        for w in words where parseCell(w.text).parallel != nil {
            guard let row = rows.min(by: { abs($0.midY - w.midY) < abs($1.midY - w.midY) }),
                  abs(row.midY - w.midY) < pitch * 0.9, w.midX - row.midX > 0.1 else { continue }
            slopes.append((w.midY - row.midY) / (w.midX - row.midX))
        }
        return slopes.median ?? 0
    }

    /// Prefers readable values, then bracketed ones (the most specific), then confidence.
    private static func score(_ cell: Kurswahl.Cell, _ box: TextBox) -> Double {
        (cell.unreadable ? 0 : 10) + (cell.parallel != nil ? 2 : 0) + (box.confidence ?? 0.5)
    }

    private static func subjectKey(_ text: String) -> String? {
        SchoolReference.subjects.first { $0.key.caseInsensitiveCompare(text) == .orderedSame }?.key
    }

    /// Common recognition slips in the subject column of a row that was not recognised at first.
    private static func misreadSubject(_ text: String) -> String? {
        if let key = subjectKey(text.replacingOccurrences(of: "0", with: "o")) { return key }
        switch text {
        case "O", "0", "Ö", "Q", "o", "DI", "D.", "D,": return "D"
        case "Mü", "Mo": return "Mu"
        case "Sp.", "5p": return "Sp"
        default: return nil
        }
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
