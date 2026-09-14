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
    /// The same photos read the way the scanner always read them, when that differs from this
    /// reading: the plan is built from both and this one kept only when its checks are not worse.
    public var original: [Kurswahl]? = nil

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
        /// Where the table's rows and columns are, for reading parts of the photo again.
        public var grid: Grid? = nil
        /// The Halbjahr columns were placed by the bracketed values, not by the numbers first taken as sums.
        public var columnsRebuilt = false
    }

    /// The table as located on the photo (0…1, top-left).
    public struct Grid: Sendable {
        /// x of the subject column.
        public var subjectX: Double
        /// x of Fachart, pro Kurs and the four Halbjahr columns.
        public var columnXs: [Double]
        public var pitch: Double
        /// Distance between neighbouring Halbjahr columns.
        public var spacing: Double
        /// Rise of a row per unit of x (the photo's tilt).
        public var slope: Double
        /// y of the sums row.
        public var bottom: Double
        public var rows: [GridRow]
    }

    public struct GridRow: Sendable {
        /// nil for a row found in a gap of the row pitch.
        public var subject: String?
        public var subjectY: Double
        /// y of the row in each of `Grid.columnXs`.
        public var ys: [Double]
        /// The four Halbjahr cells as parsed (inference included).
        public var halves: [Kurswahl.Cell]
        public var perCourse: String?
    }

    /// The sheet read twice: as it always was, and with the later additions (value and bracket read
    /// apart joined, recognition slips in cells, sums line placed by the bracketed values, Sport's
    /// hours from its Fachart, a missing cell from its sum). The additions win when more Halbjahre
    /// add up to their sums; otherwise they only fill cells the first reading left unread.
    /// `extraColumnTrigger`: the iOS column rebuild from slanted brackets or a double gap (see `slantedBracketColumn`),
    /// off by default: on degraded variants it can make rows slip at the rebuilt spacing.
    public static func parseDetailed(_ boxes: [TextBox], aspect: Double = 4.0 / 3.0, extraColumnTrigger: Bool = false) throws -> Detail {
        var enhanced = try? parseDetailed(boxes, aspect: aspect, enhanced: true, extraColumnTrigger: false)
        if extraColumnTrigger, let withTrigger = try? parseDetailed(boxes, aspect: aspect, enhanced: true, extraColumnTrigger: true),
           withTrigger.columnsRebuilt, !(enhanced?.columnsRebuilt ?? false) {
            // the columns rebuilt only by the extra trigger: kept when more sums add up, or as many with no fewer
            // cells and course numbers read (the rebuilt spacing can make rows slip)
            if let without = enhanced {
                func read(_ k: Kurswahl) -> (cells: Int, numbers: Int) {
                    let cells = k.rows.flatMap(\.halves).filter { $0.taken && $0.inferred != true }
                    return (cells.count, cells.filter { $0.parallel != nil }.count)
                }
                let a = matchedSums(withTrigger.kurswahl), b = matchedSums(without.kurswahl)
                let ra = read(withTrigger.kurswahl), rb = read(without.kurswahl)
                if a > b || (a == b && ra.cells >= rb.cells && ra.numbers >= rb.numbers) { enhanced = withTrigger }
            } else {
                enhanced = withTrigger
            }
        }
        let legacy: Detail
        do {
            legacy = try parseDetailed(boxes, aspect: aspect, enhanced: false)
        } catch {
            if let enhanced { return enhanced }
            throw error
        }
        guard let enhanced else { return legacy }
        // Halbjahre both readings placed in the same column: only there can one fill the other's gaps
        var shared: Set<Int> = [0, 1, 2, 3]
        if let a = legacy.grid?.columnXs, let b = enhanced.grid?.columnXs, a.count == 6, b.count == 6 {
            let spacing = legacy.grid?.spacing ?? 0.05
            shared = Set((0..<4).filter { abs(a[2 + $0] - b[2 + $0]) < spacing * 0.3 })
        }
        let gained = matchedSums(enhanced.kurswahl) - matchedSums(legacy.kurswahl)
        // columns placed by the brackets are evidence on their own: on a tie they win when they read
        // at least as many cells as the first reading
        func readCells(_ k: Kurswahl) -> Int { k.rows.reduce(0) { $0 + $1.halves.filter { $0.taken && $0.inferred != true }.count } }
        if gained > 0 || (enhanced.columnsRebuilt && gained == 0 && readCells(enhanced.kurswahl) >= readCells(legacy.kurswahl)) {
            // what the first reading read in the same columns still fills the additions' gaps
            var result = enhanced
            result.kurswahl = fillGaps(enhanced.kurswahl, from: legacy.kurswahl, halves: shared)
            return result
        }
        var result = legacy
        result.kurswahl = fillGaps(legacy.kurswahl, from: enhanced.kurswahl, halves: shared)
        return result
    }

    /// One of the two readings on its own: `enhanced` false is the sheet read as it always was.
    public static func parseDetailed(_ boxes: [TextBox], aspect: Double, enhanced: Bool, extraColumnTrigger: Bool = false) throws -> Detail {
        let split = boxes.flatMap { $0.words() }.map { normalised($0) }
        let words = enhanced ? split + joinedBrackets(split) : split
        let lines = boxes.map { normalised($0) }
        // the additions read cells strictly: Kursstufe courses have 2 to 5 hours, look-alike digits in brackets
        let cell: (String) -> Kurswahl.Cell = { text in enhanced ? strictCell(text) : parseCell(text) }

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
        if enhanced {
            // many subjects missed: labels two or three rows apart make that a multiple of the real pitch.
            // A row is about 1.5 times as high as its label, never lower than the label itself
            pitch = finerPitch(diffs, pitch: pitch, minimum: (found.map(\.box.height).median ?? 0) * 1.1)
        }

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
        var columnsRebuilt = false
        var sumBoxes = sumLine?.boxes ?? []
        if let row = sumLine, enhanced {
            columns = row.boxes.map(\.midX)
            sums = row.boxes.map { Int($0.text.filter(\.isNumber)) }
            slope = row.slope
            // The sums line holds more two-digit numbers right of the sums (the "Anrechnung" columns): a missed
            // sum takes the next ones and the columns land too far right. The bracketed course numbers ("5(3)")
            // are printed in the first Halbjahr column only, so the columns go where the brackets are.
            let spacingOnLine = columns.adjacentDifferences.median ?? 0
            // in a tilted photo the columns slant like the subject column: every value's x is carried down to the sums row
            let slant = columnSlant(found.map(\.box))
            let sumY = row.boxes[0].midY
            let atSums = { (w: TextBox) in w.midX + slant * (sumY - w.midY) }
            let bracketsAt = firstColumnFromBrackets(words, columns: columns, columnX: columnX, cell: cell, x: atSums)
                ?? firstColumnFromSuffixes(words, columns: columns, columnX: columnX, cell: cell, x: atSums)
                ?? (extraColumnTrigger ? slantedBracketColumn(words, line: row.boxes, spacing: spacingOnLine, cell: cell, x: atSums) : nil)
            if let bracketsAt {
                let reference = row.boxes[0]
                let onLine = words.filter { w in
                    w.text.wholeMatch(of: #/\d{2}\.?/#) != nil && w.midX > columnX + 0.12
                        && abs(w.midY - (reference.midY + slope * (w.midX - reference.midX))) < pitch * 0.6
                }
                // the printed spacing is the common small gap between the line's numbers (a missed sum leaves a
                // double gap; the "anrechenbar" column after the 4. Hj is wider)
                let gaps = onLine.map(\.midX).sorted().adjacentDifferences.filter { $0 > 0.02 }
                if let smallest = gaps.min() {
                    let gap = gaps.filter { $0 < smallest * 1.25 }.median ?? smallest
                    let rebuilt = (0..<4).map { bracketsAt + Double($0) * gap }
                    let matched = rebuilt.map { x in
                        onLine.filter { abs($0.midX - x) < gap * 0.3 }.min { abs($0.midX - x) < abs($1.midX - x) }
                    }
                    // a sum not found at its column keeps the value the line search had taken for that place
                    let lineSums = sums
                    sums = matched.enumerated().map { i, box in box.flatMap { Int($0.text.filter(\.isNumber)) } ?? lineSums[i] }
                    let snapped = rebuilt.enumerated().map { i, x in matched[i]?.midX ?? x }
                    columnsRebuilt = zip(snapped, columns).contains { abs($0 - $1) > gap * 0.3 }
                    columns = snapped
                    sumBoxes = matched.compactMap { $0 }
                }
            }
        } else if let row = sumLine {
            columns = row.boxes.map(\.midX)
            sums = row.boxes.map { Int($0.text.filter(\.isNumber)) }
            slope = row.slope
        } else {
            slope = bracketSlope(words, rows: found.map(\.box), pitch: pitch, cell: cell)
        }
        if columns.isEmpty {
            // fallback: the bracketed values "5(3)" sit in the first Halbjahr column
            let bracketed = words.filter { cell($0.text).parallel != nil }.map(\.midX)
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
        var rowYs = Array(repeating: [Double](repeating: 0, count: columnXs.count), count: rowAnchors.count)
        let top = rowAnchors[0].y - pitch * 0.7
        for (ci, cx) in columnXs.enumerated() {
            let tokens = words.filter { w in
                abs(w.midX - cx) < spacing * 0.42 && w.midY > top && w.midY < lowest - pitch * 0.3 && isValue(w.text, column: ci, cell: cell)
            }
            let predicted = ys.map { $0 + slope * (cx - lastX) }
            var best: [Int: (box: TextBox, score: Double)] = [:]
            for token in tokens {
                // each value to the one row it is nearest to
                guard let row = predicted.indices.min(by: { abs(predicted[$0] - token.midY) < abs(predicted[$1] - token.midY) }) else { continue }
                let distance = abs(predicted[row] - token.midY)
                guard distance < pitch * 0.5 else { continue }
                let score = plausibility(token, column: ci, cell: cell) - distance / pitch
                if best[row].map({ score > $0.score }) ?? true { best[row] = (token, score) }
            }
            var shifts: [Double] = []
            for (row, value) in best {
                picked[row][ci] = value.box
                shifts.append(value.box.midY - predicted[row])
            }
            // rows without a value in this column move with their neighbours
            let drift = shifts.median ?? 0
            for row in ys.indices {
                ys[row] = picked[row][ci]?.midY ?? (predicted[row] + drift)
                rowYs[row][ci] = ys[row]
            }
            lastX = cx
        }

        var rows: [Kurswahl.Row] = []
        var gridRows: [GridRow] = []
        for (index, anchor) in rowAnchors.enumerated() {
            let halves = (0..<columns.count).map { h in picked[index][2 + h].map { cell($0.text) } ?? .missing }
            let fachart = picked[index][0].map { fachartValue($0.text) }
            let perCourse = picked[index][1]?.text
            if let key = anchor.key {
                let inferred = inferMissing(halves, perCourse: perCourse, allHalves: allFourHalves.contains(key),
                                            possibleHours: enhanced ? possibleHours(key) : nil)
                rows.append(.init(subject: key, fachart: fachart, halves: inferred, perCourse: perCourse))
                gridRows.append(.init(subject: key, subjectY: anchor.y, ys: rowYs[index], halves: inferred, perCourse: perCourse))
            } else {
                gridRows.append(.init(subject: nil, subjectY: anchor.y, ys: rowYs[index], halves: halves, perCourse: perCourse))
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

        let kurswahl = Kurswahl(name: name, abiturjahr: abiturjahr, konfession: konfession,
                                rows: enhanced ? completeFromSums(rows, sums: sums) : rows, sums: sums)
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
                      sumBoxes: sumBoxes,
                      grid: Grid(subjectX: columnX, columnXs: columnXs, pitch: pitch, spacing: spacing, slope: slope,
                                 bottom: lowest, rows: gridRows),
                      columnsRebuilt: columnsRebuilt)
    }

    /// Several photos of the same sheet (an overview and close-ups), each parsed on its own, merged
    /// cell by cell: the reading most photos agree on wins, a taken value beats a "-" on a tie (a
    /// dash is what a neighbouring row lends most often), and a bracketed course number beats none.
    /// `guards` false: without dropping single-photo values that break a sum, as merging always was.
    public static func merge(_ sheets: [Kurswahl], guards: Bool = true) -> Kurswahl {
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
            let perCourse = mostCommon(versions.map(\.perCourse))
            var halves: [Kurswahl.Cell] = []
            for h in 0..<4 {
                let cells = versions.compactMap { h < $0.halves.count ? $0.halves[h] : nil }
                // with guards, a subject required in all four Halbjahre is never "-": such a reading is not a vote
                let read = cells.filter { !$0.unreadable && $0.inferred != true && (!guards || $0.taken || !allFourHalves.contains(key)) }
                guard !read.isEmpty else {
                    if guards {
                        // taken over on every photo: a possible value agreeing with "pro Kurs" first, then the most common
                        let all = cells.filter { $0.inferred == true }
                        let possible = possibleHours(key)
                        let inferred = possible.map { p in all.filter { $0.hours.map(p.contains) ?? false } }.flatMap { $0.isEmpty ? nil : $0 } ?? all
                        let hours = inferred.map(\.hours).first { $0 != nil && "\($0!)" == perCourse } ?? mostCommon(inferred.map(\.hours))
                        halves.append(inferred.first { $0.hours == hours } ?? cells.first { $0.raw != nil } ?? .missing)
                    } else {
                        halves.append(cells.first { $0.inferred == true } ?? cells.first { $0.raw != nil } ?? .missing)
                    }
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
        // with guards: a subject whose row is empty in the base but has values on another photo; the base's "?" row
        // with exactly those values (course number included) is that subject read one row off, not another subject
        let baseEmpty = Set(base.rows.filter { r in r.subject != "?" && !r.halves.contains(where: \.taken) }.map(\.subject))
        let filledElsewhere = rows.filter { r in baseEmpty.contains(r.subject) && r.halves.contains { $0.taken && $0.inferred != true } }
        for (index, row) in base.rows.enumerated() where row.subject == "?" {
            let named = recovered.first { r in
                zip(r.halves, row.halves).allSatisfy { $0.hours == $1.hours || $1.hours == nil }
            }
            if let named {
                // the photo that named the subject may have missed its course number; this row has it
                if guards, let at = rows.firstIndex(of: named) {
                    rows[at].halves = zip(named.halves, row.halves).map { a, b in
                        var cell = a
                        if a.parallel == nil, b.parallel != nil, a.hours == b.hours { cell.parallel = b.parallel }
                        return cell
                    }
                }
                continue
            }
            if guards, filledElsewhere.contains(where: { r in
                zip(r.halves, row.halves).allSatisfy { a, b in
                    a.hours == nil || b.hours == nil || (a.hours == b.hours && (a.parallel == nil || b.parallel == nil || a.parallel == b.parallel))
                } && zip(r.halves, row.halves).contains { a, b in b.parallel != nil && a.parallel == b.parallel }
            }) { continue }
            let previous = base.rows[..<index].last { $0.subject != "?" }?.subject
            let at = previous.flatMap { p in rows.firstIndex { $0.subject == p } }.map { $0 + 1 } ?? 0
            rows.insert(row, at: at)
        }

        let sums: [Int?] = (0..<4).map { h in mostCommon(sheets.map { h < $0.sums.count ? $0.sums[h] : nil }) }
        // A Halbjahr that adds up to more than its sum after merging: the usual cause is a value only one photo
        // read while the others found the row without it (a photo whose columns were placed one too far right).
        // When exactly one such value is the whole excess, it is dropped. Required subjects keep theirs.
        for h in 0..<4 where guards {
            guard let sum = sums[h] else { continue }
            let excess = rows.reduce(0) { $0 + (h < $1.halves.count ? $1.halves[h].hours ?? 0 : 0) } - sum
            guard excess > 0 else { continue }
            let lone = rows.indices.filter { r in
                let row = rows[r]
                guard h < row.halves.count, row.subject != "?", !allFourHalves.contains(row.subject) else { return false }
                let cell = row.halves[h]
                guard cell.inferred != true, cell.hours == excess else { return false }
                let versions = sheets.compactMap { sheet in sheet.rows.first { $0.subject == row.subject }.flatMap { h < $0.halves.count ? $0.halves[h] : nil } }
                return versions.filter { !$0.unreadable && $0.inferred != true && $0.hours == cell.hours }.count == 1
                    && versions.contains(where: \.unreadable)
            }
            if lone.count == 1 { rows[lone[0]].halves[h] = .missing }
        }
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

    /// `parseCell`, with recognition slips seen on real photos repaired when the text does not read as
    /// a value: "2.5" → "2.s" (the suffix read as 5), "24)" → "2(4)", "2(11" → "2(1)".
    public static func tolerantCell(_ text: String) -> Kurswahl.Cell {
        let cell = parseCell(text)
        guard cell.unreadable, cell.raw != nil else { return cell }
        let t = text.replacingOccurrences(of: " ", with: "")
        if let m = t.wholeMatch(of: #/(\d)[.,]5/#) {
            return .init(raw: text, hours: Int(m.1), parallel: nil, unreadable: false, suffix: "s")
        }
        if let m = t.wholeMatch(of: #/(\d)\(?(\d)[)1lI|]/#) {
            return .init(raw: text, hours: Int(m.1), parallel: Int(m.2), unreadable: false)
        }
        return cell
    }

    /// Subjects the Kursstufe requires in all four Halbjahre (Belegpflicht "4 Hj").
    public static let allFourHalves: Set<String> = ["D", "M", "G", "Sport"]

    /// Basisfach hours of the subjects required in all four Halbjahre; as Leistungsfach they have 5.
    static let basisHours: [String: Int] = ["D": 3, "M": 3, "G": 2, "Sport": 2]

    /// The weekly hours a subject required in all four Halbjahre can have; nil for other subjects.
    public static func possibleHours(_ subject: String) -> Set<Int>? {
        basisHours[subject].map { [$0, 5] }
    }

    /// `parseCell` as the additions read it: Kursstufe courses have 2 to 5 weekly hours, so "1", "6", "8" … is a
    /// misread (unreadable, raw kept); a digit read as a look-alike letter is accepted only in the bracketed
    /// form ("S(3)", "5(l)", "Z(1).p"); then the slips of `tolerantCell`.
    public static func strictCell(_ text: String) -> Kurswahl.Cell {
        let plain = parseCell(text)
        if let hours = plain.hours, !(2...5).contains(hours) {
            return .init(raw: text, hours: nil, parallel: nil, unreadable: true)
        }
        guard plain.unreadable, plain.raw != nil || text.contains("(") else { return plain }
        var t = normalised(TextBox(text: text, x: 0, y: 0, width: 0, height: 0)).text.replacingOccurrences(of: " ", with: "")
        for (from, to) in [("[", "("), ("{", "("), ("]", ")"), ("}", ")"), (",", "."), ("S.", "5.")] {
            t = t.replacingOccurrences(of: from, with: to)
        }
        if let m = t.wholeMatch(of: #/([0-9OoIl|SsZzB])[(C]([0-9OoIl|SsZzB])\)?(?:\.?([psPS]))?/#) {
            let lookAlikes: [Character: Int] = ["O": 0, "o": 0, "I": 1, "l": 1, "|": 1, "S": 5, "s": 5, "Z": 2, "z": 2, "B": 8]
            func value(_ s: Substring) -> Int { s.first.flatMap { $0.wholeNumberValue ?? lookAlikes[$0] } ?? -1 }
            let hours = value(m.1), parallel = value(m.2)
            if (2...5).contains(hours), (1...9).contains(parallel) {
                return .init(raw: text, hours: hours, parallel: parallel, unreadable: false, suffix: m.3.map { $0.lowercased() })
            }
        }
        let slip = tolerantCell(text)
        if let hours = slip.hours, !(2...5).contains(hours) { return plain }
        return slip
    }

    /// Cells still missing after reading, completed from the "Summen" row: every Halbjahr column adds up to
    /// its sum. A row taken in the other Halbjahre with the same hours whose cell alone is missing in a column
    /// gets its hours when the column's remainder is exactly that. A subject required in all four Halbjahre
    /// with nothing read at all gets the remainder when it is one of the subject's possible hours, or the hours
    /// its Fachart implies. A Leistungsfach cell not read is 5 when the row says 5 elsewhere, or it is the
    /// column's only gap and the remainder is 5. Cells that were read never change.
    public static func completeFromSums(_ rows: [Kurswahl.Row], sums: [Int?]) -> [Kurswahl.Row] {
        var halves = rows.map(\.halves)
        func remainder(_ h: Int, except: Int) -> Int? {
            guard h < sums.count, let sum = sums[h] else { return nil }
            return sum - halves.indices.filter { $0 != except }.reduce(0) { $0 + (h < halves[$1].count ? halves[$1][h].hours ?? 0 : 0) }
        }
        let inferredCell = { (hours: Int) in Kurswahl.Cell(raw: nil, hours: hours, parallel: nil, unreadable: false, inferred: true) }
        func fillSingleGaps() {
            for h in 0..<4 {
                guard h < sums.count, sums[h] != nil else { continue }
                // a required subject not read in this column is a gap too, so the remainder is not handed to another row
                let gaps = rows.indices.filter { i in
                    guard h < halves[i].count else { return false }
                    let cell = halves[i][h]
                    return !cell.taken && (allFourHalves.contains(rows[i].subject)
                        || (cell.unreadable && hoursElsewhere(halves[i], perCourse: rows[i].perCourse, half: h) != nil))
                }
                guard gaps.count == 1, let i = gaps.first,
                      let hours = hoursElsewhere(halves[i], perCourse: rows[i].perCourse, half: h),
                      remainder(h, except: i) == hours else { continue }
                halves[i][h] = inferredCell(hours)
            }
        }
        fillSingleGaps()
        for (i, row) in rows.enumerated() {
            guard let basis = basisHours[row.subject], halves[i].count == 4, !halves[i].contains(where: \.taken) else { continue }
            let possible: Set<Int> = [basis, 5]
            let votes = (0..<4).compactMap { h in remainder(h, except: i).flatMap { possible.contains($0) ? $0 : nil } }
            let byFachart: Int? = switch row.fachart {
            case "L": 5
            case "B", "m": basis
            default: nil
            }
            let hours: Int?
            if votes.isEmpty {
                hours = byFachart
            } else if Set(votes).count == 1, votes.count >= 2 || byFachart == votes[0] {
                hours = votes[0]
            } else if let byFachart, votes.contains(byFachart) {
                hours = byFachart
            } else {
                hours = nil
            }
            guard let hours else { continue }
            for h in 0..<4 { halves[i][h] = inferredCell(hours) }
        }
        for (i, row) in rows.enumerated() where row.fachart == "L" && halves[i].count == 4 {
            let backed = row.perCourse == "5" || halves[i].contains { $0.hours == 5 && $0.inferred != true }
            for h in 0..<4 {
                let cell = halves[i][h]
                guard !cell.taken, cell.unreadable else { continue }
                let onlyGap = !rows.indices.contains { j in
                    guard j != i, h < halves[j].count else { return false }
                    let other = halves[j][h]
                    return !other.taken && (allFourHalves.contains(rows[j].subject) || other.raw != nil
                        || hoursElsewhere(halves[j], perCourse: rows[j].perCourse, half: h) != nil)
                }
                if backed || (onlyGap && remainder(h, except: i) == 5) { halves[i][h] = inferredCell(5) }
            }
        }
        fillSingleGaps()
        return rows.enumerated().map { i, row in
            var copy = row
            copy.halves = halves[i]
            return copy
        }
    }

    /// The hours a row has in the Halbjahre other than `half`, when those read agree (and "pro Kurs" does not contradict).
    static func hoursElsewhere(_ halves: [Kurswahl.Cell], perCourse: String?, half: Int) -> Int? {
        // a "-" read in another Halbjahr: the subject is not taken throughout, so it says nothing about this one
        if halves.enumerated().contains(where: { $0.offset != half && !$0.element.taken && !$0.element.unreadable }) { return nil }
        let at = halves.indices.filter { $0 != half && halves[$0].taken && halves[$0].inferred != true }
        let others = at.map { halves[$0] }
        guard !others.isEmpty, !others.contains(where: { $0.suffix != nil }) else { return nil }
        // a course of two Halbjahre ("2.p", "2.s", the suffix not read) must not pass for one taken throughout:
        // the other readings have to be three, or lie on both sides of this Halbjahr, or not be neighbours
        guard let firstAt = at.first, let lastAt = at.last,
              at.count >= 3 || (firstAt < half && half < lastAt) || (at.count == 2 && at[1] - at[0] > 1) else { return nil }
        guard let hours = others[0].hours, others.allSatisfy({ $0.hours == hours }) else { return nil }
        if let pro = perCourse.flatMap({ Int($0) }), pro != hours { return nil }
        return hours
    }

    /// The row pitch when `pitch` is a multiple of it: at least three neighbouring subjects about a half or a
    /// third of `pitch` apart, and that finer pitch explains more of the distances as whole rows. Never below
    /// `minimum`: labels of two recognition passes a little apart are not rows.
    static func finerPitch(_ diffs: [Double], pitch: Double, minimum: Double = 0) -> Double {
        func explained(_ p: Double) -> Int {
            diffs.filter { d in
                let n = Int((d / p).rounded())
                return n >= 1 && abs(d - Double(n) * p) < p * 0.2
            }.count
        }
        // most distances already whole rows of `pitch`: nothing to refine
        if Double(explained(pitch)) >= Double(diffs.count) * 0.8 { return pitch }
        var best = pitch
        for k in 2...3 {
            let rows = diffs.filter { abs($0 - pitch / Double(k)) < pitch / Double(k) * 0.25 }
            guard rows.count >= 3, let finer = rows.median, finer >= minimum else { continue }
            if explained(finer) > explained(best) { best = finer }
        }
        return best
    }

    /// The x of the first Halbjahr column when the bracketed course numbers are densest one or two columns left
    /// of `columns` (where a missed first sum puts them); nil when they are where the columns say.
    /// `x`: a box's x at the height of the sums row (the photo's tilt taken out).
    static func firstColumnFromBrackets(_ words: [TextBox], columns: [Double], columnX: Double, cell: (String) -> Kurswahl.Cell,
                                        x: (TextBox) -> Double = { $0.midX }) -> Double? {
        guard let spacing = columns.adjacentDifferences.median, spacing > 0 else { return nil }
        let xs = words.filter { $0.midX > columnX + 0.05 && cell($0.text).parallel != nil }.map(x)
        guard let at = densestX(xs, window: spacing * 0.3), xs.filter({ abs($0 - at) < spacing * 0.3 }).count >= 3 else { return nil }
        let shift = Int(((at - columns[0]) / spacing).rounded())
        guard (-2...(-1)).contains(shift), abs(at - (columns[0] + Double(shift) * spacing)) < spacing * 0.3 else { return nil }
        return at
    }

    /// The x of the first Halbjahr column, one column left of `columns`, when too few brackets were read for
    /// `firstColumnFromBrackets`: a plain "2.p" / "2.s" sits in the column taken for the first Halbjahr, no
    /// bracketed value does, and the column to its left has one.
    static func firstColumnFromSuffixes(_ words: [TextBox], columns: [Double], columnX: Double, cell: (String) -> Kurswahl.Cell,
                                        x: (TextBox) -> Double = { $0.midX }) -> Double? {
        guard let spacing = columns.adjacentDifferences.median, spacing > 0 else { return nil }
        func cells(_ at: Double) -> [Kurswahl.Cell] {
            words.filter { $0.midX > columnX + 0.05 && abs(x($0) - at) < spacing * 0.3 }.map { cell($0.text) }
        }
        let first = cells(columns[0])
        guard !first.contains(where: { $0.parallel != nil }), first.contains(where: { $0.suffix != nil && $0.parallel == nil }) else { return nil }
        let left = columns[0] - spacing
        return cells(left).contains { $0.parallel != nil } ? left : nil
    }

    /// iOS addition to the two above: in a rotated photo the columns slant like the subject column, so each
    /// bracket's x is carried down to the sums row first; the columns are rebuilt when those brackets sit more
    /// than half a column away from the first sum, or the four sums found leave a double gap (a missed sum).
    static func slantedBracketColumn(_ words: [TextBox], line: [TextBox], spacing: Double,
                                     cell: (String) -> Kurswahl.Cell, x: (TextBox) -> Double) -> Double? {
        guard spacing > 0, let first = line.first else { return nil }
        let brackets = words.filter { cell($0.text).parallel != nil && $0.midY < first.midY }.map(x)
        let gaps = line.map(\.midX).adjacentDifferences
        let doubleGap = gaps.min().map { smallest in gaps.contains { $0 > smallest * 1.6 } } ?? false
        guard brackets.count >= 3, let at = densestX(brackets, window: 0.02),
              abs(at - first.midX) > spacing * 0.5 || doubleGap else { return nil }
        return at
    }

    /// How far the subject column's x moves per unit of y (least squares): the columns of a tilted photo slant the same way.
    static func columnSlant(_ subjects: [TextBox]) -> Double {
        guard subjects.count >= 2 else { return 0 }
        let ys = subjects.map(\.midY), xs = subjects.map(\.midX)
        let meanY = ys.reduce(0, +) / Double(ys.count), meanX = xs.reduce(0, +) / Double(xs.count)
        let varianceY = ys.reduce(0) { $0 + ($1 - meanY) * ($1 - meanY) }
        return varianceY > 0 ? zip(xs, ys).reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) } / varianceY : 0
    }

    /// Android's `fillGaps`: `base` with the cells it did not read taken from `extra`, a reading of the same photo
    /// with more text (enlarged bands). A cell read in `base` never changes; values taken over from the rest of the
    /// sheet are worked out again afterwards, so they agree with what was newly read.
    public static func completeGaps(_ base: Kurswahl, extra: Kurswahl) -> Kurswahl {
        func read(_ cell: Kurswahl.Cell) -> Bool { !cell.unreadable && cell.inferred != true }
        let sums = base.sums.enumerated().map { h, sum in sum ?? (h < extra.sums.count ? extra.sums[h] : nil) }
        let rows = base.rows.map { row -> Kurswahl.Row in
            guard row.subject != "?", let other = extra.rows.first(where: { $0.subject == row.subject }),
                  row.halves.count == 4, other.halves.count == 4 else { return row }
            let halves = row.halves.enumerated().map { h, cell -> Kurswahl.Cell in
                if read(cell) { return cell }
                if read(other.halves[h]) { return other.halves[h] }
                return cell.inferred == true ? .missing : cell
            }
            guard halves.enumerated().contains(where: { $0.element != row.halves[$0.offset] && read($0.element) }) else { return row }
            var copy = row
            copy.fachart = row.fachart ?? other.fachart
            copy.perCourse = row.perCourse ?? other.perCourse
            copy.halves = inferMissing(halves, perCourse: copy.perCourse, allHalves: allFourHalves.contains(row.subject),
                                       possibleHours: possibleHours(row.subject))
            return copy
        }
        var result = base
        result.rows = completeFromSums(rows, sums: sums)
        result.sums = sums
        return result
    }

    /// A Halbjahr cell that was not read, taken over when the other three agree on plain hours
    /// (a subject taken all four Halbjahre) and "pro Kurs" does not contradict. For a subject
    /// required every Halbjahr (`allHalves`) a gap or dash is a misread, and "pro Kurs" gives the hours.
    /// `possibleHours`: the hours a required subject can have; a "pro Kurs" or other value outside them belongs to a
    /// neighbouring row, and a "-" is then a misread (missing, not a reading that could outvote another photo).
    static func inferMissing(_ halves: [Kurswahl.Cell], perCourse: String?, allHalves: Bool = false,
                             possibleHours: Set<Int>? = nil) -> [Kurswahl.Cell] {
        guard halves.count == 4 else { return halves }
        var result = halves
        for i in halves.indices where !halves[i].taken {
            if allHalves {
                func possible(_ hours: Int?) -> Int? { hours.flatMap { possibleHours == nil || possibleHours!.contains($0) ? $0 : nil } }
                if let hours = possible(perCourse.flatMap { Int($0) }) ?? possible(mostCommon(halves.map(\.hours))) {
                    result[i] = .init(raw: nil, hours: hours, parallel: nil, unreadable: false, inferred: true)
                } else if possibleHours != nil, !halves[i].unreadable {
                    result[i] = .missing
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

    /// Fills what `base` left open with what `other` (the same photo read again) found: an unread or
    /// unreadable cell gets a read value, an inferred cell becomes read when the hours agree, a
    /// missing course number, Fachart or "pro Kurs" is added, and a "?" row takes the name of a
    /// subject the base lacks when it sits after the same subject and its hours agree. Nothing the
    /// base read is changed; rows only the other reading has are added after their predecessor.
    /// `halves`: the Halbjahre both readings placed in the same column; rows are only named or added
    /// when that is all four.
    public static func fillGaps(_ base: Kurswahl, from other: Kurswahl, halves: Set<Int> = [0, 1, 2, 3]) -> Kurswahl {
        var result = base
        let allColumns = halves == [0, 1, 2, 3]
        func previousName(_ rows: [Kurswahl.Row], before index: Int) -> String? {
            rows[..<index].last { $0.subject != "?" }?.subject
        }
        var used = Set<Int>()
        for i in result.rows.indices {
            let row = result.rows[i]
            let match: Int?
            if row.subject == "?" {
                guard allColumns else { continue }
                match = other.rows.indices.first { j in
                    let candidate = other.rows[j]
                    guard !used.contains(j), candidate.subject != "?", !result.rows.contains(where: { $0.subject == candidate.subject }),
                          previousName(other.rows, before: j) == previousName(result.rows, before: i) else { return false }
                    let pairs = zip(row.halves, candidate.halves).filter { $0.taken && $1.taken }
                    return !pairs.isEmpty && pairs.allSatisfy { $0.hours == $1.hours }
                }
                if let match { result.rows[i].subject = other.rows[match].subject }
            } else {
                match = other.rows.firstIndex { $0.subject == row.subject }
            }
            guard let j = match else { continue }
            used.insert(j)
            let source = other.rows[j]
            if result.rows[i].fachart == nil { result.rows[i].fachart = source.fachart }
            if result.rows[i].perCourse == nil { result.rows[i].perCourse = source.perCourse }
            for h in 0..<min(result.rows[i].halves.count, source.halves.count) where halves.contains(h) {
                let mine = result.rows[i].halves[h], theirs = source.halves[h]
                guard theirs.taken, theirs.inferred != true else { continue }
                if !mine.taken {
                    // a dash that was read stays a dash
                    if mine.raw == nil || mine.unreadable { result.rows[i].halves[h] = theirs }
                } else if mine.hours == theirs.hours {
                    if mine.inferred == true { result.rows[i].halves[h] = theirs }
                    if result.rows[i].halves[h].parallel == nil, let parallel = theirs.parallel {
                        result.rows[i].halves[h].parallel = parallel
                    }
                }
            }
        }
        // rows only the other reading found, with something read in them
        for (j, row) in other.rows.enumerated() where allColumns && !used.contains(j) && row.subject != "?" {
            guard !result.rows.contains(where: { $0.subject == row.subject }),
                  row.halves.contains(where: { $0.taken && $0.inferred != true }) else { continue }
            // the base has it already as an unnamed row: adding it would count its hours twice
            let unnamed = result.rows.contains { other in
                guard other.subject == "?" else { return false }
                let pairs = zip(other.halves, row.halves).filter { $0.taken && $1.taken }
                return !pairs.isEmpty && pairs.allSatisfy { $0.hours == $1.hours }
            }
            guard !unnamed else { continue }
            let previous = previousName(other.rows, before: j)
            let at = previous.flatMap { p in result.rows.firstIndex { $0.subject == p } }.map { $0 + 1 } ?? 0
            result.rows.insert(row, at: at)
        }
        for h in result.sums.indices where result.sums[h] == nil && h < other.sums.count && halves.contains(h) {
            result.sums[h] = other.sums[h]
        }
        return result
    }

    /// Halbjahre whose sum was read and equals the hours taken in them.
    public static func matchedSums(_ kurswahl: Kurswahl) -> Int {
        (0..<min(4, kurswahl.sums.count)).filter { h in
            kurswahl.sums[h] != nil
                && kurswahl.rows.reduce(0, { $0 + (h < $1.halves.count ? $1.halves[h].hours ?? 0 : 0) }) == kurswahl.sums[h]
        }.count
    }

    /// "5" and "(3)" recognised as two boxes side by side on one line, as one more box "5(3)" (the two stay):
    /// on one line when their centres are less than 0.6 of the taller box apart, and the bracket starts between a
    /// digit width before the digit's end and two digit widths (plus a little) after it; the nearest bracket.
    static func joinedBrackets(_ words: [TextBox]) -> [TextBox] {
        let brackets = words.filter { $0.text.wholeMatch(of: #/[(\[{]\d[)\]}]?(?:\.?[psPS])?/#) != nil }
        guard !brackets.isEmpty else { return [] }
        return words.filter { $0.text.wholeMatch(of: #/\d/#) != nil }.compactMap { digit in
            guard let bracket = brackets.filter({ b in
                let gap = b.x - digit.maxX
                return abs(b.midY - digit.midY) < max(digit.height, b.height) * 0.6
                    && gap >= -digit.width && gap <= digit.width * 2 + 0.004
            }).min(by: { abs($0.x - digit.maxX) < abs($1.x - digit.maxX) }) else { return nil }
            let y = min(digit.y, bracket.y)
            return TextBox(text: digit.text + bracket.text, x: digit.x, y: y,
                           width: bracket.maxX - digit.x, height: max(digit.maxY, bracket.maxY) - y,
                           confidence: min(digit.confidence ?? 0.5, bracket.confidence ?? 0.5))
        }
    }

    /// Nothing left to improve: every sum read and matched, no inferred, unreadable or unnamed cell.
    public static func isComplete(_ kurswahl: Kurswahl) -> Bool {
        guard kurswahl.sums.count == 4, kurswahl.sums.allSatisfy({ $0 != nil }) else { return false }
        let matched = (0..<4).allSatisfy { h in
            kurswahl.rows.reduce(0, { $0 + (h < $1.halves.count ? $1.halves[h].hours ?? 0 : 0) }) == kurswahl.sums[h]
        }
        return matched && kurswahl.rows.allSatisfy { row in
            row.subject != "?" && row.halves.allSatisfy { $0.inferred != true && !($0.unreadable && $0.raw != nil) }
        }
    }

    private static func isValue(_ text: String, column: Int, cell: (String) -> Kurswahl.Cell) -> Bool {
        switch column {
        case 0: return ["L", "B", "m", "L/B", "LB", "UB", "L/8"].contains(text)
        case 1: return text.wholeMatch(of: #/\d(/\d)?/#) != nil
        default:
            let value = cell(text)
            return value.hours != nil || value.raw != nil
        }
    }

    private static func fachartValue(_ text: String) -> String {
        ["LB", "UB", "L/8"].contains(text) ? "L/B" : text
    }

    /// How much a token looks like the value its column holds, 0…~1.2; distance is taken off separately.
    private static func plausibility(_ token: TextBox, column: Int, cell: (String) -> Kurswahl.Cell) -> Double {
        let confidence = (token.confidence ?? 0.5) * 0.1
        guard column >= 2 else { return 1 + confidence }
        let value = cell(token.text)
        return (value.unreadable ? 0.3 : 1) + (value.parallel != nil ? 0.15 : 0) + confidence
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
    private static func bracketSlope(_ words: [TextBox], rows: [TextBox], pitch: Double, cell: (String) -> Kurswahl.Cell) -> Double {
        var slopes: [Double] = []
        for w in words where cell(w.text).parallel != nil {
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
