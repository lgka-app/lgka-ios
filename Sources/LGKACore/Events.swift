import Foundation

/// School events scraper — Swift port of the app's `_parseWeekHtml` + the
/// aggregation in `fetchUpcomingEvents` (events_service.dart), verified
/// against the events goldens.
public enum EventsParser {
    public struct Event: Sendable, Hashable {
        public let date: String // "yyyy-MM-dd"
        public let time: String?
        public let title: String
    }

    private static var liRe: Regex<(Substring, Substring)> { #/(?is)<li\s+class=["']ev_td_li["'][^>]*>(.*?)<\/li>/# }
    private static var hrefRe: Regex<(Substring, Substring, Substring, Substring)> { #/href="[^"]*?\/icalrepeat\.detail\/(\d{4})\/(\d{2})\/(\d{2})\//# }
    private static var titleRe: Regex<(Substring, Substring)> { #/title="([^"]+)"/# }
    private static var timeRe: Regex<(Substring, Substring)> { #/(\d{1,2}:\d{2})\s*Uhr/# }

    static func parseWeekHtml(_ html: String, today: String) -> [Event] {
        var events: [Event] = []
        for m in html.matches(of: liRe) {
            let li = String(m.1)
            guard let h = li.firstMatch(of: hrefRe) else { continue }
            let date = "\(h.1)-\(h.2)-\(h.3)"
            if date < today { continue } // ISO strings compare like dates
            guard let t = li.firstMatch(of: titleRe) else { continue }
            let title = decodeEntities(t.1.trimmingCharacters(in: .whitespacesAndNewlines))
            if title.isEmpty { continue }
            let time = li.firstMatch(of: timeRe).map { String($0.1) }
            events.append(Event(date: date, time: time, title: title))
        }
        return events
    }

    /// Mirror of fetchUpcomingEvents aggregation: dedup + stable sort ascending.
    public static func upcoming(weekHtmls: [String], today: String) -> [Event] {
        var all: [Event] = []
        var seen = Set<String>()
        for html in weekHtmls {
            for e in parseWeekHtml(html, today: today) {
                let key = "\(e.date)T00:00:00.000|\(e.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
                if seen.insert(key).inserted { all.append(e) }
            }
        }
        // stable sort by date (Swift's sort is not guaranteed stable)
        return all.enumerated()
            .sorted { a, b in
                a.element.date != b.element.date
                    ? a.element.date < b.element.date : a.offset < b.offset
            }
            .map(\.element)
    }

    /// Golden-shaped output (`date` as a Dart ISO timestamp, `time` nullable).
    public static func aggregate(weekHtmls: [String], today: String) -> [[String: Any]] {
        upcoming(weekHtmls: weekHtmls, today: today).map {
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
