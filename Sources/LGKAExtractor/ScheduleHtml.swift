import Foundation
import SwiftSoup

/// Schedule page scraper — Swift port of the app's `_parseScheduleHtml`
/// (schedule_service.dart), verified against the stundenplan_page goldens.
enum ScheduleHtmlParser {
    static let base = "https://lessing-gymnasium-karlsruhe.de"

    static func parse(_ html: String) throws -> [[String: Any]] {
        let doc = try SwiftSoup.parse(html)
        guard let module = try doc.select("#mod-custom213").first() else {
            throw NSError(domain: "lgka", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Serververbindung fehlgeschlagen"])
        }
        var schedules: [[String: Any]] = []
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
                    of: "/cm3/../", with: "\(base)/",
                    options: .anchored)
            } else if href.hasPrefix("/") {
                fullUrl = "\(base)\(href)"
            }
            if seenUrls.contains(fullUrl) { continue }
            seenUrls.insert(fullUrl)

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

            schedules.append([
                "title": title, "url": href, "halbjahr": halbjahr,
                "gradeLevel": gradeLevel, "fullUrl": fullUrl,
            ])
        }
        if schedules.isEmpty {
            throw NSError(domain: "lgka", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Serververbindung fehlgeschlagen"])
        }
        return schedules
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
