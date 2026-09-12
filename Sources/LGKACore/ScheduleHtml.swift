import Foundation
import SwiftSoup

/// Schedule page scraper — Swift port of the app's `_parseScheduleHtml`
/// (schedule_service.dart), verified against the stundenplan_page goldens.
public enum ScheduleHtmlParser {
    static let base = "https://lessing-gymnasium-karlsruhe.de"

    public struct Schedule: Sendable, Hashable, Identifiable {
        public var id: String { fullUrl }
        public let title: String
        public let url: String
        public let halbjahr: String
        public let gradeLevel: String
        public let fullUrl: String

        /// Grades this PDF covers, discovered from the link title: "… - 5-10" → 5…10,
        /// "… - J11" → [11], "… - J11/12" or "11-12" → [11, 12], "… - J13" → [13].
        /// Empty when the title carries no grade (the app then falls back to `gradeLevel`).
        public var grades: [Int] { ScheduleGrades.fromTitle(title) }

        /// Does this PDF contain `cls` ("10b" → grade 10, "j11" → grade 11)?
        public func covers(_ cls: String) -> Bool {
            guard let grade = ScheduleGrades.gradeOf(cls) else { return false }
            return grades.contains(grade)
        }
    }

    public static func schedules(_ html: String) throws -> [Schedule] {
        let doc = try SwiftSoup.parse(html)
        guard let module = try doc.select("#mod-custom213").first() else {
            throw LGKAError.scheduleModuleMissing
        }
        var schedules: [Schedule] = []
        var seenUrls = Set<String>()

        for link in try module.select("a[href*=stundenplan]").array() {
            let href = try link.attr("href")
            if href.isEmpty { continue }
            let linkText = rawText(link).trimmingCharacters(in: .whitespacesAndNewlines)
            let title = linkText.isEmpty ? (try link.attr("title")) : linkText
            if title.isEmpty { continue }

            var fullUrl = href
            if href.hasPrefix("/cm3/../") {
                fullUrl = href.replacingOccurrences(
                    of: "/cm3/../", with: "\(base)/", options: .anchored)
            } else if href.hasPrefix("/") {
                fullUrl = "\(base)\(href)"
            }
            if !seenUrls.insert(fullUrl).inserted { continue }

            let halbjahr: String
            if href.contains("hj2") { halbjahr = "2. Halbjahr" }
            else if href.contains("hj1") { halbjahr = "1. Halbjahr" }
            else if title.contains("1.HJ") { halbjahr = "1. Halbjahr" }
            else if title.contains("2.HJ") { halbjahr = "2. Halbjahr" }
            else { halbjahr = "Unbekannt" }

            let gradeLevel: String
            if title.contains("5-10") { gradeLevel = "Klassen 5-10" }
            else if title.contains("J11/12") || title.contains("11-12") { gradeLevel = "J11/J12" }
            else { gradeLevel = "Unbekannt" }

            schedules.append(Schedule(title: title, url: href, halbjahr: halbjahr,
                                      gradeLevel: gradeLevel, fullUrl: fullUrl))
        }
        if schedules.isEmpty { throw LGKAError.noSchedulesFound }
        return schedules
    }

    /// Golden-shaped output.
    public static func parse(_ html: String) throws -> [[String: Any]] {
        try schedules(html).map {
            ["title": $0.title, "url": $0.url, "halbjahr": $0.halbjahr,
             "gradeLevel": $0.gradeLevel, "fullUrl": $0.fullUrl]
        }
    }
}

/// Dart `.text`: concatenation of descendant TEXT NODES only (no "\n"
/// synthesis for <br>). Shared by all HTML parsers in this target.
func rawText(_ element: Element) -> String {
    var out = ""
    func walk(_ node: Node) {
        if let tn = node as? TextNode { out += tn.getWholeText() }
        for child in node.getChildNodes() { walk(child) }
    }
    walk(element)
    return out
}

/// Grade discovery shared by the schedule list and the PDF viewer, so a new
/// Jahrgang (J13, a split "J11" / "J12" upload, …) needs no app update.
public enum ScheduleGrades {
    /// Grades named in a schedule link title; ranges ("5-10", "11-12") are expanded,
    /// "J11", "J11/12", "J 13" are read as Jahrgang numbers.
    public static func fromTitle(_ title: String) -> [Int] {
        // only the part after the last " - " names the grades ("Stundenpläne - 2026/2027 - 1.HJ - J11")
        let tail = title.components(separatedBy: " - ").last ?? title
        var grades = Set<Int>()
        for m in tail.matches(of: #/(\d{1,2})\s*-\s*(\d{1,2})/#) {
            if let a = Int(m.1), let b = Int(m.2), a <= b, b - a < 20 { grades.formUnion(a...b) }
        }
        for m in tail.matches(of: #/[Jj]\s*(\d{1,2})(?:\s*/\s*(\d{1,2}))?/#) {
            if let a = Int(m.1) { grades.insert(a) }
            if let second = m.2, let b = Int(second) { grades.insert(b) }
        }
        return grades.sorted()
    }

    /// "10b" → 10, "j11" → 11, "J13" → 13; nil for anything else.
    public static func gradeOf(_ cls: String) -> Int? {
        let lower = cls.lowercased()
        if let m = lower.wholeMatch(of: #/j(\d{1,2})/#) { return Int(m.1) }
        if let m = lower.wholeMatch(of: #/(\d{1,2})[a-e]/#) { return Int(m.1) }
        return nil
    }

    /// Is `cls` a class or Jahrgang token the app accepts ("5a"…"10e", "j11", "j13", …)?
    public static func isClassToken(_ cls: String) -> Bool { gradeOf(cls) != nil }
}
