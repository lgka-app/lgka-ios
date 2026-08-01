import Foundation

/// School events scraper — Swift port of the app's `_parseWeekHtml` + the
/// aggregation in `fetchUpcomingEvents` (events_service.dart), verified
/// against the events goldens.
public enum EventsParser {
    struct Event {
        let date: String // "yyyy-MM-dd"
        let time: String?
        let title: String
    }

    private static let liRe = try! NSRegularExpression(
        pattern: "<li\\s+class=[\"']ev_td_li[\"'][^>]*>(.*?)</li>",
        options: [.dotMatchesLineSeparators, .caseInsensitive])
    private static let hrefRe = try! NSRegularExpression(
        pattern: "href=\"[^\"]*?/icalrepeat\\.detail/(\\d{4})/(\\d{2})/(\\d{2})/")
    private static let titleRe = try! NSRegularExpression(pattern: "title=\"([^\"]+)\"")
    private static let timeRe = try! NSRegularExpression(pattern: "(\\d{1,2}:\\d{2})\\s*Uhr")

    private static func groups(_ re: NSRegularExpression, _ s: String) -> [String]? {
        let range = NSRange(s.startIndex..., in: s)
        guard let m = re.firstMatch(in: s, range: range) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            guard let r = Range(m.range(at: i), in: s) else { return "" }
            return String(s[r])
        }
    }

    static func parseWeekHtml(_ html: String, today: String) -> [Event] {
        var events: [Event] = []
        let range = NSRange(html.startIndex..., in: html)
        for m in liRe.matches(in: html, range: range) {
            guard let liRange = Range(m.range(at: 1), in: html) else { continue }
            let li = String(html[liRange])
            guard let h = groups(hrefRe, li) else { continue }
            let date = "\(h[1])-\(h[2])-\(h[3])"
            if date < today { continue } // ISO strings compare like dates
            guard var title = groups(titleRe, li)?[1]
                .trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
            title = decodeEntities(title)
            if title.isEmpty { continue }
            let time = groups(timeRe, li)?[1]
            events.append(Event(date: date, time: time, title: title))
        }
        return events
    }

    /// Mirror of fetchUpcomingEvents aggregation: dedup + sort ascending.
    public static func aggregate(weekHtmls: [String], today: String) -> [[String: Any]] {
        var all: [Event] = []
        var seen = Set<String>()
        for html in weekHtmls {
            for e in parseWeekHtml(html, today: today) {
                let key = "\(e.date)T00:00:00.000|\(e.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
                if !seen.contains(key) {
                    seen.insert(key)
                    all.append(e)
                }
            }
        }
        // stable sort by date (Swift's sort is not guaranteed stable)
        let sorted = all.enumerated()
            .sorted { a, b in
                a.element.date != b.element.date
                    ? a.element.date < b.element.date : a.offset < b.offset
            }
            .map(\.element)
        return sorted.map {
            ["date": "\($0.date)T00:00:00.000",
             "time": $0.time as Any? ?? NSNull(),
             "title": $0.title]
        }
    }

    private static func decodeEntities(_ s: String) -> String {
        var r = s
        for (from, to) in [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
            ("&#39;", "'"), ("&nbsp;", " "), ("&auml;", "ä"), ("&ouml;", "ö"),
            ("&uuml;", "ü"), ("&Auml;", "Ä"), ("&Ouml;", "Ö"), ("&Uuml;", "Ü"),
            ("&szlig;", "ß"),
        ] {
            r = r.replacingOccurrences(of: from, with: to)
        }
        return r
    }
}
