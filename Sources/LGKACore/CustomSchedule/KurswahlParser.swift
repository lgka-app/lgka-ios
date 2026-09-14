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
        /// The "pro Kurs" column: "5", "2", "5/3" (not chosen yet).
        public var perCourse: String?

        public init(subject: String, fachart: String?, halves: [Cell], label: String? = nil, perCourse: String? = nil) {
            self.subject = subject
            self.fachart = fachart
            self.halves = halves
            self.label = label
            self.perCourse = perCourse
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
        /// "p" / "s" of a subject taken in two Halbjahre only ("2.p").
        public var suffix: String?
        /// Not read but taken over from the subject's other three Halbjahre.
        public var inferred: Bool?

        public init(raw: String?, hours: Int?, parallel: Int?, unreadable: Bool, suffix: String? = nil, inferred: Bool? = nil) {
            self.raw = raw
            self.hours = hours
            self.parallel = parallel
            self.unreadable = unreadable
            self.suffix = suffix
            self.inferred = inferred
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
/// the four Halbjahr columns. Rows are then followed column by column (Fachart, pro Kurs, 1.–4. Hj):
/// every value belongs to the one row it is nearest to, and each row's height is carried over
/// from the value found in the previous column, so a curved or skewed sheet stays on its rows.
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
        try parseDetailed(boxes, aspect: aspect).kurswahl
    }

    /// The parsed sheet plus what was found where, for live scanning.
    public struct Detail: Sendable {
        public var kurswahl: Kurswahl
        /// Table rows between the header and the sums: estimated from the row pitch once both are seen.
        public var tableRows: Int
        /// Per Halbjahr column: rows whose cell was read ("-" included).
        public var readCells: [Int]
        public var subjectBoxes: [TextBox]
        /// Per Halbjahr column: the boxes read in it.
        public var cellBoxes: [[TextBox]]
        public var sumBoxes: [TextBox]
    }

    public static func parseDetailed(_ boxes: [TextBox], aspect: Double = 4.0 / 3.0) throws -> Detail {
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

        // Halbjahr columns and tilt from the sums row ("Summen", or the numbers under the table)
        let summen = lines.first(where: { $0.text.lowercased().hasPrefix("summen") })
            ?? words.first(where: { $0.text.lowercased().hasPrefix("summen") })
        var columns: [Double] = []
        var sums: [Int?] = [nil, nil, nil, nil]
        var slope = 0.0
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
        let lowest = summen?.midY ?? sumLine?.boxes.first?.midY ?? (lastRowY + pitch)
        let rowAnchors = anchors.filter { $0.y < lowest - pitch * 0.5 }
        guard !rowAnchors.isEmpty else { throw Failure.noSubjects }

        // follow the rows column by column: Fachart, pro Kurs, then the four Halbjahre
        let columnXs = [columns[0] - spacing * 2, columns[0] - spacing] + columns
        var ys = rowAnchors.map(\.y)
        var lastX = columnX
        var picked = Array(repeating: [TextBox?](repeating: nil, count: columnXs.count), count: rowAnchors.count)
        let top = rowAnchors[0].y - pitch * 0.7
        for (ci, cx) in columnXs.enumerated() {
            let tokens = words.filter { w in
                abs(w.midX - cx) < spacing * 0.42 && w.midY > top && w.midY < lowest - pitch * 0.3 && isValue(w.text, column: ci)
            }
            let predicted = ys.map { $0 + slope * (cx - lastX) }
            var best: [Int: (box: TextBox, score: Double)] = [:]
            for token in tokens {
                // each value to the one row it is nearest to
                guard let row = predicted.indices.min(by: { abs(predicted[$0] - token.midY) < abs(predicted[$1] - token.midY) }) else { continue }
                let distance = abs(predicted[row] - token.midY)
                guard distance < pitch * 0.5 else { continue }
                let score = plausibility(token, column: ci) - distance / pitch
                if best[row].map({ score > $0.score }) ?? true { best[row] = (token, score) }
            }
            var shifts: [Double] = []
            for (row, value) in best {
                picked[row][ci] = value.box
                shifts.append(value.box.midY - predicted[row])
            }
            // rows without a value in this column move with their neighbours
            let drift = shifts.median ?? 0
            for row in ys.indices { ys[row] = picked[row][ci]?.midY ?? (predicted[row] + drift) }
            lastX = cx
        }

        var rows: [Kurswahl.Row] = []
        for (index, anchor) in rowAnchors.enumerated() {
            let halves = (0..<columns.count).map { h in picked[index][2 + h].map { parseCell($0.text) } ?? .missing }
            let fachart = picked[index][0].map { fachartValue($0.text) }
            let perCourse = picked[index][1]?.text
            if let key = anchor.key {
                rows.append(.init(subject: key, fachart: fachart,
                                  halves: inferMissing(halves, perCourse: perCourse, allHalves: allFourHalves.contains(key)),
                                  perCourse: perCourse))
            } else {
                // a gap row: only worth keeping when something is taken in it
                guard halves.contains(where: \.taken) else { continue }
                let label = words.filter { abs($0.midX - columnX) < 0.04 && abs($0.midY - anchor.y) < pitch * 0.42 }.map(\.text).first
                rows.append(.init(subject: label.flatMap(misreadSubject) ?? "?", fachart: fachart,
                                  halves: inferMissing(halves, perCourse: perCourse), label: label, perCourse: perCourse))
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

        let kurswahl = Kurswahl(name: name, abiturjahr: abiturjahr, konfession: konfession, rows: rows, sums: sums)
        var tableRows = rowAnchors.count
        let headerY = lines.filter { line in headerTexts.contains { line.text.lowercased().contains($0) } && line.midY < rowAnchors[0].y }
            .map(\.midY).max()
        if let headerY, let sumY = sumLine?.boxes.first?.midY ?? summen?.midY {
            tableRows = max(tableRows, Int(((sumY - headerY) / pitch).rounded()) - 1)
        }
        return Detail(kurswahl: kurswahl, tableRows: tableRows,
                      readCells: columns.indices.map { h in picked.filter { $0[2 + h] != nil }.count },
                      subjectBoxes: found.map(\.box),
                      cellBoxes: columns.indices.map { h in picked.compactMap { $0[2 + h] } },
                      sumBoxes: sumLine?.boxes ?? [])
    }

    /// Several photos of the same sheet (an overview and close-ups), each parsed on its own, merged
    /// cell by cell: the reading most photos agree on wins, a taken value beats a "-" on a tie (a
    /// dash is what a neighbouring row lends most often), and a bracketed course number beats none.
    public static func merge(_ sheets: [Kurswahl]) -> Kurswahl {
        let known = { (sheet: Kurswahl) in sheet.rows.filter { $0.subject != "?" }.count }
        guard let base = sheets.max(by: { known($0) < known($1) }) else {
            return Kurswahl(name: nil, abiturjahr: nil, konfession: nil, rows: [], sums: [nil, nil, nil, nil])
        }
        guard sheets.count > 1 else { return base }

        // subjects in sheet order: the base's, others inserted after their predecessor
        var order = base.rows.map(\.subject).filter { $0 != "?" }
        for sheet in sheets {
            var previous: String?
            for row in sheet.rows where row.subject != "?" {
                if !order.contains(row.subject) {
                    let at = previous.flatMap { order.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
                    order.insert(row.subject, at: at)
                }
                previous = row.subject
            }
        }

        var rows: [Kurswahl.Row] = []
        for key in order {
            let versions = sheets.flatMap { $0.rows.filter { $0.subject == key } }
            var halves: [Kurswahl.Cell] = []
            for h in 0..<4 {
                let cells = versions.compactMap { h < $0.halves.count ? $0.halves[h] : nil }
                let read = cells.filter { !$0.unreadable && $0.inferred != true }
                guard !read.isEmpty else {
                    halves.append(cells.first { $0.inferred == true } ?? cells.first { $0.raw != nil } ?? .missing)
                    continue
                }
                var counts: [Int: Int] = [:] // hours, -1 = not taken
                for cell in read { counts[cell.hours ?? -1, default: 0] += 1 }
                let winner = read.map { $0.hours ?? -1 }.max { a, b in
                    let ca = counts[a] ?? 0, cb = counts[b] ?? 0
                    return ca != cb ? ca < cb : (a == -1 && b != -1)
                } ?? -1
                let agreeing = read.filter { ($0.hours ?? -1) == winner }
                var chosen = agreeing.first { $0.parallel != nil } ?? agreeing[0]
                if let parallel = mostCommon(agreeing.map(\.parallel)) { chosen.parallel = parallel }
                halves.append(chosen)
            }
            rows.append(.init(subject: key, fachart: mostCommon(versions.map(\.fachart)), halves: halves,
                              perCourse: mostCommon(versions.map(\.perCourse))))
        }

        // unrecognised rows of the base stay unless another photo named that subject
        let baseKnown = Set(base.rows.map(\.subject))
        let recovered = rows.filter { !baseKnown.contains($0.subject) }
        for (index, row) in base.rows.enumerated() where row.subject == "?" {
            let named = recovered.contains { r in
                zip(r.halves, row.halves).allSatisfy { $0.hours == $1.hours || $1.hours == nil }
            }
            guard !named else { continue }
            let previous = base.rows[..<index].last { $0.subject != "?" }?.subject
            let at = previous.flatMap { p in rows.firstIndex { $0.subject == p } }.map { $0 + 1 } ?? 0
            rows.insert(row, at: at)
        }

        let sums: [Int?] = (0..<4).map { h in mostCommon(sheets.map { h < $0.sums.count ? $0.sums[h] : nil }) }
        return Kurswahl(name: sheets.lazy.compactMap(\.name).first,
                        abiturjahr: sheets.lazy.compactMap(\.abiturjahr).first,
                        konfession: sheets.lazy.compactMap(\.konfession).first,
                        rows: rows, sums: sums)
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
            return .init(raw: text, hours: Int(m.1), parallel: m.2.flatMap { Int($0) }, unreadable: false,
                         suffix: m.3.map { $0.lowercased() })
        }
        // specks and table lines read as "..E" are not a value; only text with a digit is worth asking about
        let unreadable = t.contains(where: \.isNumber)
        return .init(raw: unreadable ? text : nil, hours: nil, parallel: nil, unreadable: unreadable)
    }

    /// Subjects the Kursstufe requires in all four Halbjahre (Belegpflicht "4 Hj").
    static let allFourHalves: Set<String> = ["D", "M", "G", "Sport"]

    /// A Halbjahr cell that was not read, taken over when the other three agree on plain hours
    /// (a subject taken all four Halbjahre) and "pro Kurs" does not contradict. For a subject
    /// required every Halbjahr (`allHalves`) a gap or dash is a misread, and "pro Kurs" gives the hours.
    static func inferMissing(_ halves: [Kurswahl.Cell], perCourse: String?, allHalves: Bool = false) -> [Kurswahl.Cell] {
        guard halves.count == 4 else { return halves }
        var result = halves
        for i in halves.indices where !halves[i].taken {
            if allHalves {
                if let hours = perCourse.flatMap({ Int($0) }) ?? mostCommon(halves.map(\.hours)) {
                    result[i] = .init(raw: nil, hours: hours, parallel: nil, unreadable: false, inferred: true)
                }
                continue
            }
            guard halves[i].unreadable else { continue }
            let others = halves.enumerated().filter { $0.offset != i }.map(\.element)
            guard others.allSatisfy({ $0.taken && $0.suffix == nil }),
                  let hours = others.first?.hours, others.allSatisfy({ $0.hours == hours }),
                  perCourse.flatMap({ Int($0) }).map({ $0 == hours }) ?? true else { continue }
            result[i] = .init(raw: nil, hours: hours, parallel: nil, unreadable: false, inferred: true)
        }
        return result
    }

    private static func isValue(_ text: String, column: Int) -> Bool {
        switch column {
        case 0: return ["L", "B", "m", "L/B", "LB", "UB", "L/8"].contains(text)
        case 1: return text.wholeMatch(of: #/\d(/\d)?/#) != nil
        default:
            let cell = parseCell(text)
            return cell.hours != nil || cell.raw != nil
        }
    }

    private static func fachartValue(_ text: String) -> String {
        ["LB", "UB", "L/8"].contains(text) ? "L/B" : text
    }

    /// How much a token looks like the value its column holds, 0…~1.2; distance is taken off separately.
    private static func plausibility(_ token: TextBox, column: Int) -> Double {
        let confidence = (token.confidence ?? 0.5) * 0.1
        guard column >= 2 else { return 1 + confidence }
        let cell = parseCell(token.text)
        return (cell.unreadable ? 0.3 : 1) + (cell.parallel != nil ? 0.15 : 0) + confidence
    }

    /// The four Halbjahr sums: two-digit numbers on one straight line through `anchor` ("Summen",
    /// or the first sum). The photo may be tilted, so the line is searched, not assumed horizontal.
    private static func sumRow(_ words: [TextBox], anchor: TextBox, columnX: Double, pitch: Double) -> (boxes: [TextBox], slope: Double)? {
        let numbers = words.filter { w in
            w.midX > columnX + 0.12 && abs(w.midY - anchor.midY) < pitch * 4 && w.text.wholeMatch(of: #/\d{2}\.?/#) != nil
        }
        var best: (boxes: [TextBox], slope: Double)?
        for candidate in numbers {
            let dx = candidate.midX - anchor.midX
            guard dx > 0.05 else { continue }
            let slope = (candidate.midY - anchor.midY) / dx
            guard abs(slope) < 0.2 else { continue }
            let onLine = numbers
                .filter { $0.midX >= anchor.midX - 0.01 && abs($0.midY - (anchor.midY + slope * ($0.midX - anchor.midX))) < pitch * 0.5 }
                .sorted { $0.midX < $1.midX }
                .reduce(into: [TextBox]()) { acc, w in
                    if let last = acc.last, abs(last.midX - w.midX) < 0.02 { return }
                    acc.append(w)
                }
            if onLine.count >= 4, onLine.count > (best?.boxes.count ?? 0) {
                let first4 = Array(onLine.prefix(4))
                let reference = first4[0].midX - anchor.midX > 0.05 ? anchor : first4[0]
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

    private static func mostCommon<T: Hashable>(_ values: [T?]) -> T? {
        let present = values.compactMap { $0 }
        var counts: [T: Int] = [:]
        for value in present { counts[value, default: 0] += 1 }
        return present.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
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
