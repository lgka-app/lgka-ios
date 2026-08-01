import Foundation
import SwiftSoup

/// News scraper — Swift port of NewsService (news_service.dart), verified
/// against the news goldens.
///
/// Parity notes vs the Dart `html` package (mirrors the Kotlin port):
///  - Dart `.text` returns RAW concatenated text nodes -> rawText() walks
///    TextNodes directly (SwiftSoup .text() would collapse whitespace, and
///    wholeText-style APIs synthesize "\n" for <br>).
///  - Dart `attributes['x']` is null when absent, "" when present-empty.
///  - Dart innerHtml escapes &<>" plus nbsp (as &nbsp;), leaves umlauts raw
///    -> SwiftSoup EscapeMode.base + prettyPrint(false) + UTF-8.
public enum NewsParser {
    static let base = "https://lessing-gymnasium-karlsruhe.de"

    private static func absolutize(_ href: String) -> String {
        if href.hasPrefix("http") { return href }
        if href.hasPrefix("/") { return "\(base)\(href)" }
        return "\(base)/cm3/\(href)"
    }

    private static func configure(_ doc: Document) {
        doc.outputSettings()
            .prettyPrint(pretty: false)
            .escapeMode(Entities.EscapeMode.base)
            .syntax(syntax: .html) // Dart serializes void tags as <br>, not <br />
            .charset(String.Encoding.utf8)
    }

    private static func attrOrNil(_ e: Element, _ name: String) -> String? {
        e.hasAttr(name) ? (try? e.attr(name)) : nil
    }

    private static func trim(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // ---- list page metadata ------------------------------------------------

    public struct Metadata {
        public let title: String, author: String, description: String
        public let createdDate: String, parsedDateIso: String?
        public let views: Int, url: String, tags: [String]
    }

    public static func parseListPage(_ html: String) throws -> [Metadata] {
        let doc = try SwiftSoup.parse(html)
        configure(doc)
        var out: [Metadata] = []
        for item in try doc.select(".blog-item").array() {
            guard let titleElement = try item.select("h2 a").first() else { continue }
            let title = trim(rawText(titleElement))
            let articleUrl = (try? titleElement.attr("href")) ?? ""
            let fullUrl = articleUrl.hasPrefix("http") ? articleUrl : "\(base)\(articleUrl)"

            var author = "Unknown"
            if let el = try item.select(".createdby").first() {
                let t = rawText(el)
                if t.contains("Geschrieben von") {
                    author = trim(trim(t.replacingOccurrences(of: "Geschrieben von", with: ""))
                        .components(separatedBy: "\n").first ?? "")
                }
            }

            var createdDate = "Unknown"
            var parsedDateIso: String? = nil
            if let el = try item.select(".create").first() {
                let t = rawText(el)
                if t.contains("Erstellt:") {
                    createdDate = trim(trim(t.replacingOccurrences(of: "Erstellt:", with: ""))
                        .components(separatedBy: "\n").first ?? "")
                    parsedDateIso = parseGermanDate(createdDate)
                }
            }

            var views = 0
            if let el = try item.select(".hits").first() {
                let t = rawText(el)
                if t.contains("Zugriffe:") {
                    let digits = trim(t.replacingOccurrences(of: "Zugriffe:", with: ""))
                        .replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                    views = Int(digits) ?? 0
                }
            }

            var description = ""
            if let el = try item.select(".item-content").first() {
                let ps = try el.select("p").array().map { trim(rawText($0)) }.filter { !$0.isEmpty }
                if !ps.isEmpty { description = ps.prefix(2).joined(separator: " ") }
            }

            var tags: [String] = []
            if let tc = try item.select("ul.tags.list-inline").first() {
                tags = try tc.select("a").array().map { trim(rawText($0)) }.filter { !$0.isEmpty }
            }

            out.append(Metadata(title: title, author: author, description: description,
                                createdDate: createdDate, parsedDateIso: parsedDateIso,
                                views: views, url: fullUrl, tags: tags))
        }
        return out
    }

    /// DD.MM.YYYY -> midnight Europe/Berlin, Dart TZDateTime-style ISO; nil otherwise.
    private static func parseGermanDate(_ s: String) -> String? {
        let parts = s.components(separatedBy: ".")
        guard parts.count == 3,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        let tz = TimeZone(identifier: "Europe/Berlin")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var comp = DateComponents()
        comp.year = year; comp.month = month; comp.day = day
        guard let date = cal.date(from: comp) else { return nil }
        let off = tz.secondsFromGMT(for: date)
        let sign = off < 0 ? "-" : "+"
        let absOff = abs(off)
        return String(format: "%04d-%02d-%02dT00:00:00.000%@%02d%02d",
                      year, month, day, sign, absOff / 3600, (absOff % 3600) / 60)
    }

    // ---- article page ------------------------------------------------------

    public struct Article {
        public let content: String?, htmlContent: String?
        public let links: [[String: String]], standaloneLinks: [[String: String]]
        public let images: [[String: Any]], downloads: [[String: Any]]
    }

    private static let emptyArticle = Article(
        content: nil, htmlContent: nil, links: [], standaloneLinks: [], images: [], downloads: [])

    private static func isStandalone(_ link: Element, _ text: String,
                                     _ href: String, _ fullUrl: String) -> Bool {
        guard let parent = link.parent(),
              parent.tagName() == "p" || parent.tagName() == "div" else { return false }
        let parentText = trim(rawText(parent))
        return text == fullUrl || text == href ||
            (text.hasPrefix("http") && parentText == text) ||
            (text.hasPrefix("http") && parentText.count <= text.count + 5)
    }

    public static func parseArticle(_ html: String) throws -> Article {
        let doc = try SwiftSoup.parse(html)
        configure(doc)
        guard let body = try doc.select(".com-content-article__body").first() else {
            return emptyArticle
        }

        // downloads
        var downloads: [[String: Any]] = []
        for dl in try body.select("a.doclink-insert").array() {
            let href = (try? dl.attr("href")) ?? ""
            if href.isEmpty { continue }
            let fullUrl = absolutize(href)
            var title = attrOrNil(dl, "data-title") ?? ""
            if title.isEmpty {
                title = trim(trim(rawText(dl)).replacingOccurrences(
                    of: "\\s*\\([^)]+\\)\\s*$", with: "", options: .regularExpression))
            }
            var fileType = "document"
            if let span = try dl.select("span[class*=k-icon-document]").first() {
                for cn in (try? span.classNames()) ?? [] where cn.hasPrefix("k-icon-document-") {
                    fileType = String(cn.dropFirst("k-icon-document-".count))
                    break
                }
            }
            if fileType == "document",
               let span = try dl.select("span.k-visually-hidden").first() {
                let t = trim(rawText(span)).lowercased()
                if !t.isEmpty { fileType = t }
            }
            var size: String? = nil
            let fullText = rawText(dl)
            if let r = fullText.range(of: "\\(([^)]+)\\)", options: .regularExpression) {
                let inner = String(fullText[r].dropFirst().dropLast())
                let candidate = trim(inner)
                if candidate.range(of: "\\d+\\s*(MB|KB|GB|B|bytes?)",
                                   options: [.regularExpression, .caseInsensitive]) != nil {
                    size = candidate
                }
            }
            var entry: [String: Any] = ["title": title, "url": fullUrl, "file_type": fileType]
            if let s = size { entry["size"] = s }
            downloads.append(entry)
        }

        // links (embedded vs standalone)
        var embedded: [[String: String]] = []
        var standalone: [[String: String]] = []
        for link in try body.select("a").array() {
            if ((try? link.classNames()) ?? []).contains("doclink-insert") { continue }
            guard let href = attrOrNil(link, "href"), !href.isEmpty else { continue }
            let text = trim(rawText(link))
            if text.isEmpty { continue }
            let fullUrl = absolutize(href)
            let entry = ["text": text, "url": fullUrl]
            if isStandalone(link, text, href, fullUrl) { standalone.append(entry) }
            else { embedded.append(entry) }
        }

        // images: galleries first, then non-gallery <img>
        var images: [[String: Any]] = []
        for gallery in try body.select(".sigFreeContainer").array() {
            for link in try gallery.select("a.sigFreeLink").array() {
                guard let imageUrl = attrOrNil(link, "href"), !imageUrl.isEmpty else { continue }
                let thumbnailUrl = attrOrNil(link, "data-thumb")
                let img = try link.select("img").first()
                let alt = img.flatMap { attrOrNil($0, "alt") ?? attrOrNil($0, "title") }
                var entry: [String: Any] = ["url": absolutize(imageUrl)]
                if let t = thumbnailUrl, !t.isEmpty { entry["thumbnail_url"] = absolutize(t) }
                if let a = alt { entry["alt"] = a }
                images.append(entry)
            }
        }
        for img in try body.select("img").array() {
            if ((try? img.classNames()) ?? []).contains("sigFreeImg") { continue }
            guard let src = attrOrNil(img, "src"), !src.isEmpty else { continue }
            let fullImageUrl = absolutize(src)
            if !images.contains(where: { ($0["url"] as? String) == fullImageUrl }) {
                var entry: [String: Any] = ["url": fullImageUrl]
                if let a = attrOrNil(img, "alt") { entry["alt"] = a }
                images.append(entry)
            }
        }

        // cloned body with downloads + standalone links removed
        let clone = body.copy() as! Element
        for dl in try clone.select("a.doclink-insert").array() { try dl.remove() }
        for link in try clone.select("a:not(.doclink-insert)").array() {
            guard let href = attrOrNil(link, "href"), !href.isEmpty else { continue }
            let text = trim(rawText(link))
            if text.isEmpty { continue }
            let fullUrl = absolutize(href)
            if isStandalone(link, text, href, fullUrl) { try link.remove() }
        }

        func cleanHtml(_ h: String) -> String {
            // SwiftSoup hardcodes XML-style " />" on void tags regardless of
            // the syntax setting; Dart serializes them as ">". Text nodes
            // escape ">" as &gt;, so this replacement only touches tags.
            let voidFixed = h.replacingOccurrences(
                of: "\\s*/>", with: ">", options: .regularExpression)
            return trim(voidFixed.replacingOccurrences(of: "<!--.*?-->", with: "",
                options: [.regularExpression, .caseInsensitive]))
        }

        let paragraphs = try clone.select("p").array()
        let htmlContent: String
        let content: String
        if paragraphs.isEmpty {
            htmlContent = cleanHtml(try clone.html())
            content = trim(rawText(clone))
        } else {
            htmlContent = paragraphs.compactMap { try? cleanHtml($0.html()) }
                .filter { !$0.isEmpty }.joined(separator: "\n\n")
            content = paragraphs.map { trim(rawText($0)) }
                .filter { !$0.isEmpty }.joined(separator: "\n\n")
        }

        return Article(content: content, htmlContent: htmlContent,
                       links: embedded, standaloneLinks: standalone,
                       images: images, downloads: downloads)
    }

    // ---- aggregation -------------------------------------------------------

    public static func run(listHtml: String, urlToFile: [String: String],
                    readFile: (String) throws -> String) throws -> [[String: Any]] {
        let metadata = try parseListPage(listHtml)
        var events: [[String: Any]] = []
        for md in metadata {
            let article: Article
            if let file = urlToFile[md.url] {
                article = try parseArticle(readFile(file))
            } else {
                article = emptyArticle
            }
            var e: [String: Any] = [
                "title": md.title, "author": md.author, "description": md.description,
            ]
            if let c = article.content { e["content"] = c }
            if let h = article.htmlContent { e["html_content"] = h }
            e["created_date"] = md.createdDate
            e["views"] = md.views
            e["url"] = md.url
            e["links"] = article.links
            e["standalone_links"] = article.standaloneLinks
            e["images"] = article.images
            e["downloads"] = article.downloads
            e["tags"] = md.tags
            e["parsed_date"] = md.parsedDateIso as Any? ?? NSNull()
            events.append(e)
        }
        // stable newest-first sort by parsed_date; undated keep original order
        return events.enumerated()
            .sorted { a, b in
                let pa = a.element["parsed_date"] as? String
                let pb = b.element["parsed_date"] as? String
                switch (pa, pb) {
                case let (x?, y?): return x != y ? y < x : a.offset < b.offset
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.offset < b.offset
                }
            }
            .map(\.element)
    }
}
