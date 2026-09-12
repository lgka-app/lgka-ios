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
