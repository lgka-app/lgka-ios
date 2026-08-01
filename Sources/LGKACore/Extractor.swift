import Foundation

/// Substitution-plan extractor — Swift port of the reference implementation
/// (verification repo, lib/extractor_v2.dart). Must reproduce the `expected`
/// objects of the "goldens/substitution" v2 goldens exactly.
///
/// Port note vs the Dart reference: char-level clustering merges same-height
/// header blocks (school / "SJ ..." / "Untis ...") into one visual line, so
/// the pre-title meta zone is re-split into segments on x-gaps > 15pt before
/// classification. Everything below the title anchors per visual line.
public enum Extractor {
    private static let weekdays = [
        "Montag", "Dienstag", "Mittwoch", "Donnerstag",
        "Freitag", "Samstag", "Sonntag",
    ]

    private static let columnNames = [
        "type", "period", "classes", "substitute", "subject", "room",
        "originalSubject", "originalTeacher", "originalRoom", "note",
    ]

    private static let segmentGap = 15.0

    public static func extract(lines: [Line]) -> [String: Any] {
        var plan: [String: Any] = [
            "school": NSNull(), "address": NSNull(), "schoolYear": NSNull(),
            "untisVersion": NSNull(), "generatedAt": NSNull(),
            "planDate": NSNull(), "weekday": NSNull(), "isEmpty": false,
            "announcements": [String](), "absentTeachers": [String](),
            "absentClasses": [String](), "entries": [[String: Any]](),
            "footer": [String: Any](),
        ]

        let totalLength = lines
            .map { $0.text.trimmingCharacters(in: .whitespaces).count }
            .reduce(0, +)
        if totalLength < 50 {
            plan["isEmpty"] = true
            return plan
        }

        // ---- classify anchor lines ---------------------------------------
        var titleIdx: Int?, teachersIdx: Int?, classesIdx: Int?
        var headerIdx: Int?, footerIdx: Int?
        for (i, line) in lines.enumerated() {
            let t = line.text.trimmingCharacters(in: .whitespaces)
            if titleIdx == nil, t.contains("Klassen"), t.contains("/"),
               weekdays.contains(where: t.contains) {
                titleIdx = i
            } else if t.hasPrefix("Abwesende Lehrer") {
                teachersIdx = i
            } else if t.hasPrefix("Abwesende Klassen") {
                classesIdx = i
            } else if headerIdx == nil, t.hasPrefix("Art"), t.contains("Stunde") {
                headerIdx = i
            } else if firstMatch(#"\d{1,2}\.\d{1,2}\.\d{4}\s*\(\d+\)\s*SJ\s"#, t) != nil {
                footerIdx = i
            }
        }

        // ---- meta zone: segment same-height blocks, classify each --------
        for i in 0..<(titleIdx ?? lines.count) {
            for segment in segments(of: lines[i]) {
                let t = segment.trimmingCharacters(in: .whitespaces)
                if firstMatch(#"^SJ \d{4}-\d{4}$"#, t) != nil {
                    plan["schoolYear"] = t
                } else if t.hasPrefix("Untis ") {
                    plan["untisVersion"] = t
                } else if firstMatch(#"^\d{1,2}\.\d{1,2}\.\d{4}\s+\d{1,2}:\d{2}$"#, t) != nil {
                    plan["generatedAt"] = collapse(t)
                } else if plan["school"] is NSNull {
                    plan["school"] = t
                } else if plan["address"] is NSNull {
                    plan["address"] = t
                }
            }
        }

        // ---- footer -------------------------------------------------------
        var footerYear: String?
        if let fi = footerIdx {
            let text = collapse(lines[fi].text)
            if let g = firstMatch(
                #"(?:Periode\s+(\d+)\s+)?(\d{1,2})\.(\d{1,2})\.(\d{4})\s+\((\d+)\)\s+SJ\s+(\S+)"#,
                text) {
                footerYear = g[4]
                plan["footer"] = [
                    "untisPeriod": g[1].flatMap { Int($0) } as Any? ?? NSNull(),
                    "date": "\(pad(g[2]!)).\(pad(g[3]!)).\(g[4]!)",
                    "calendarWeek": Int(g[5]!)!,
                    "schoolYearShort": "SJ \(g[6]!)",
                ] as [String: Any]
            }
        }

        // ---- title --------------------------------------------------------
        if let ti = titleIdx,
           let g = firstMatch(#"(\d{1,2})\.(\d{1,2})\.\s*/\s*(\w+)"#, lines[ti].text) {
            plan["weekday"] = g[3]!
            if let year = footerYear {
                plan["planDate"] = "\(pad(g[1]!)).\(pad(g[2]!)).\(year)"
            }
        }

        // ---- announcements ------------------------------------------------
        let annEnd = [teachersIdx, classesIdx, headerIdx, footerIdx, lines.count]
            .compactMap { $0 }.min()!
        if let ti = titleIdx {
            var announcements: [String] = []
            for i in (ti + 1)..<annEnd {
                let t = collapse(lines[i].text.trimmingCharacters(in: .whitespaces))
                if !t.isEmpty { announcements.append(t) }
            }
            plan["announcements"] = announcements
        }

        // ---- absences -----------------------------------------------------
        func valuesAfterColon(_ line: Line) -> [String] {
            guard let colon = line.text.firstIndex(of: ":") else { return [] }
            return line.text[line.text.index(after: colon)...]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        if let i = teachersIdx { plan["absentTeachers"] = valuesAfterColon(lines[i]) }
        if let i = classesIdx { plan["absentClasses"] = valuesAfterColon(lines[i]) }

        // ---- table --------------------------------------------------------
        if let hi = headerIdx {
            var xs: [Double] = []
            var lastRight: Double?
            for w in lines[hi].words where !w.text.isEmpty {
                if xs.isEmpty || w.left - lastRight! > 3 { xs.append(w.left) }
                lastRight = w.right
            }
            precondition(xs.count == columnNames.count,
                         "expected \(columnNames.count) columns, found \(xs.count): \(xs)")

            func columnOf(_ left: Double) -> Int {
                for c in xs.indices.reversed() where left >= xs[c] - 3 { return c }
                return 0
            }

            var entries: [[String: Any]] = []
            var currentIdx: Int?
            let tableEnd = footerIdx ?? lines.count
            for i in (hi + 1)..<tableEnd {
                var cells = [String](repeating: "", count: columnNames.count)
                var prevCol: Int?
                var prevRight: Double?
                for w in lines[i].words {
                    let t = w.text.trimmingCharacters(in: .whitespaces)
                    if t.isEmpty { continue }
                    let c = columnOf(w.left)
                    if cells[c].isEmpty {
                        cells[c] = t
                    } else if c == prevCol, w.left - prevRight! <= 3 {
                        cells[c] += t // glyph fragment of the same word
                    } else {
                        cells[c] += " " + t
                    }
                    prevCol = c
                    prevRight = w.right
                }
                if cells.allSatisfy(\.isEmpty) { continue }

                if !cells[0].isEmpty || !cells[1].isEmpty {
                    var entry: [String: Any] = [:]
                    for c in columnNames.indices {
                        entry[columnNames[c]] = cells[c].isEmpty ? NSNull() : cells[c]
                    }
                    entry["classesRaw"] = cells[2].isEmpty ? NSNull() : cells[2]
                    entry["classes"] = expandClasses(cells[2])
                    entries.append(entry)
                    currentIdx = entries.count - 1
                } else if let ci = currentIdx {
                    for c in columnNames.indices {
                        if cells[c].isEmpty || columnNames[c] == "classes" { continue }
                        let prev = entries[ci][columnNames[c]] as? String
                        entries[ci][columnNames[c]] =
                            prev == nil ? cells[c] : "\(prev!) \(cells[c])"
                    }
                }
            }
            plan["entries"] = entries
        }

        return plan
    }

    /// "6ab" -> [6a, 6b]; "5a, 7c" -> [5a, 7c]; "J11" -> [J11].
    private static func expandClasses(_ cell: String) -> [String] {
        var out: [String] = []
        for part in cell.split(separator: ",") {
            let p = part.trimmingCharacters(in: .whitespaces)
            if p.isEmpty { continue }
            if let g = firstMatch(#"^(\d{1,2})([a-e]{2,})$"#, p) {
                for letter in g[2]! { out.append("\(g[1]!)\(letter)") }
            } else {
                out.append(p)
            }
        }
        return out
    }

    /// Splits a visual line into text segments on x-gaps > `segmentGap`.
    private static func segments(of line: Line) -> [String] {
        var out: [String] = []
        var current = ""
        var prevRight: Double?
        for w in line.words {
            if !current.isEmpty, w.left - prevRight! > segmentGap {
                out.append(current)
                current = ""
            }
            if !current.isEmpty { current += " " }
            current += w.text
            prevRight = w.right
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    // ---- small helpers ----------------------------------------------------

    /// First regex match; returns capture groups (index 0 = whole match).
    private static func firstMatch(_ pattern: String, _ text: String) -> [String?]? {
        let re = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            guard r.location != NSNotFound, let sr = Range(r, in: text) else { return nil }
            return String(text[sr])
        }
    }

    private static func collapse(_ s: String) -> String {
        s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func pad(_ s: String) -> String {
        s.count >= 2 ? s : "0" + s
    }
}
