import Foundation

/// Substitution-plan extractor — Swift port of the reference implementation
/// (verification repo, lib/extractor_v2.dart). Must reproduce the `expected`
/// objects of the "goldens/substitution" v2 goldens exactly.
///
/// Port note vs the Dart reference: char-level clustering merges same-height
/// header blocks (school / "SJ ..." / "Untis ...") into one visual line, so
/// the pre-title meta zone is re-split into segments on x-gaps > 15pt before
/// classification. Everything below the title anchors per visual line.
///
/// All regular expressions are compile-time checked Swift regex literals;
/// a structurally unexpected PDF throws `LGKAError` instead of trapping.
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

    private static var footerAnchor: Regex<Substring> { #/\d{1,2}\.\d{1,2}\.\d{4}\s*\(\d+\)\s*SJ\s/# }
    private static var schoolYearRe: Regex<Substring> { #/SJ \d{4}-\d{4}/# }
    private static var generatedAtRe: Regex<Substring> { #/\d{1,2}\.\d{1,2}\.\d{4}\s+\d{1,2}:\d{2}/# }
    private static var footerRe: Regex<(Substring, Substring?, Substring, Substring, Substring, Substring, Substring)> { #/(?:Periode\s+(\d+)\s+)?(\d{1,2})\.(\d{1,2})\.(\d{4})\s+\((\d+)\)\s+SJ\s+(\S+)/# }
    private static var titleRe: Regex<(Substring, Substring, Substring, Substring)> { #/(\d{1,2})\.(\d{1,2})\.\s*\/\s*(\w+)/# }
    private static var classRangeRe: Regex<(Substring, Substring, Substring)> { #/(\d{1,2})([a-e]{2,})/# }

    public static func extract(lines: [Line]) throws -> [String: Any] {
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
            } else if t.contains(footerAnchor) {
                footerIdx = i
            }
        }

        // ---- meta zone: segment same-height blocks, classify each --------
        for i in 0..<(titleIdx ?? lines.count) {
            for segment in segments(of: lines[i]) {
                let t = segment.trimmingCharacters(in: .whitespaces)
                if t.wholeMatch(of: schoolYearRe) != nil {
                    plan["schoolYear"] = t
                } else if t.hasPrefix("Untis ") {
                    plan["untisVersion"] = t
                } else if t.wholeMatch(of: generatedAtRe) != nil {
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
        if let fi = footerIdx, let g = collapse(lines[fi].text).firstMatch(of: footerRe) {
            footerYear = String(g.4)
            plan["footer"] = [
                "untisPeriod": g.1.flatMap { Int($0) } as Any? ?? NSNull(),
                "date": "\(pad(g.2)).\(pad(g.3)).\(g.4)",
                "calendarWeek": Int(g.5) ?? 0,
                "schoolYearShort": "SJ \(g.6)",
            ] as [String: Any]
        }

        // ---- title --------------------------------------------------------
        if let ti = titleIdx, let g = lines[ti].text.firstMatch(of: titleRe) {
            plan["weekday"] = String(g.3)
            if let year = footerYear {
                plan["planDate"] = "\(pad(g.1)).\(pad(g.2)).\(year)"
            }
        }

        // ---- announcements ------------------------------------------------
        let annEnd = [teachersIdx, classesIdx, headerIdx, footerIdx]
            .compactMap { $0 }.min() ?? lines.count
        if let ti = titleIdx, ti + 1 <= annEnd {
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
            var lastRight = -Double.infinity
            for w in lines[hi].words where !w.text.isEmpty {
                if xs.isEmpty || w.left - lastRight > 3 { xs.append(w.left) }
                lastRight = w.right
            }
            guard xs.count == columnNames.count else {
                throw LGKAError.unexpectedTableHeader(found: xs.count, expected: columnNames.count)
            }

            func columnOf(_ left: Double) -> Int {
                for c in xs.indices.reversed() where left >= xs[c] - 3 { return c }
                return 0
            }

            var entries: [[String: Any]] = []
            var currentIdx: Int?
            let tableEnd = footerIdx ?? lines.count
            if hi + 1 < tableEnd {
                for i in (hi + 1)..<tableEnd {
                    var cells = [String](repeating: "", count: columnNames.count)
                    var prevCol: Int?
                    var prevRight = -Double.infinity
                    for w in lines[i].words {
                        let t = w.text.trimmingCharacters(in: .whitespaces)
                        if t.isEmpty { continue }
                        let c = columnOf(w.left)
                        if cells[c].isEmpty {
                            cells[c] = t
                        } else if c == prevCol, w.left - prevRight <= 3 {
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
                            if let prev = entries[ci][columnNames[c]] as? String {
                                entries[ci][columnNames[c]] = "\(prev) \(cells[c])"
                            } else {
                                entries[ci][columnNames[c]] = cells[c]
                            }
                        }
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
            if let g = p.wholeMatch(of: classRangeRe) {
                for letter in g.2 { out.append("\(g.1)\(letter)") }
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
        var prevRight = -Double.infinity
        for w in line.words {
            if !current.isEmpty, w.left - prevRight > segmentGap {
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

    private static func collapse(_ s: String) -> String {
        s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func pad(_ s: Substring) -> String {
        s.count >= 2 ? String(s) : "0" + s
    }
}
