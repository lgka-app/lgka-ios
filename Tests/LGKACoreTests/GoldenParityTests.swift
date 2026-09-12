import Foundation
import Testing
@testable import LGKACore

/// Locates the lgka-app/verification checkout. CI clones it next to the
/// repo as `verification`; locally `lgka-verification` also works, and
/// `LGKA_VERIFICATION_DIR` overrides both.
enum Goldens {
    static let root: URL? = {
        if let env = ProcessInfo.processInfo.environment["LGKA_VERIFICATION_DIR"] {
            return URL(fileURLWithPath: env)
        }
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for name in ["verification", "lgka-verification"] {
            let candidate = repo.deletingLastPathComponent().appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("goldens").path) {
                return candidate
            }
        }
        return nil
    }()

    static func golden(_ relative: String) throws -> [String: Any] {
        let url = try #require(root).appendingPathComponent(relative)
        let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return try #require(obj as? [String: Any])
    }

    static func list(_ dir: String, suffix: String, prefix: String = "") throws -> [String] {
        let url = try #require(root).appendingPathComponent(dir)
        return try FileManager.default.contentsOfDirectory(atPath: url.path)
            .filter { $0.hasSuffix(suffix) && $0.hasPrefix(prefix) }.sorted()
    }

    static func file(_ relative: String) throws -> URL {
        try #require(root).appendingPathComponent(relative)
    }

    static func text(_ relative: String) throws -> String {
        try String(contentsOf: file(relative), encoding: .utf8)
    }

    /// Semantic JSON equality like the Rust comparator: numbers compare as
    /// Double, `null` equals NSNull, key order is irrelevant.
    static func diff(_ golden: Any, _ actual: Any, path: String = "", into out: inout [String]) {
        switch (golden, actual) {
        case let (g as [String: Any], a as [String: Any]):
            for k in Set(g.keys).union(a.keys).sorted() {
                let p = path.isEmpty ? k : "\(path).\(k)"
                switch (g[k], a[k]) {
                case let (gv?, av?): diff(gv, av, path: p, into: &out)
                case (_?, nil): out.append("\(p): missing in actual")
                case (nil, _?): out.append("\(p): unexpected in actual")
                default: break
                }
            }
        case let (g as [Any], a as [Any]):
            if g.count != a.count { out.append("\(path).length: \(g.count) vs \(a.count)") }
            for (i, (gv, av)) in zip(g, a).enumerated() { diff(gv, av, path: "\(path)[\(i)]", into: &out) }
        case let (g as NSNumber, a as NSNumber):
            if g.doubleValue != a.doubleValue { out.append("\(path): \(g) vs \(a)") }
        case (is NSNull, is NSNull): break
        case let (g as String, a as String):
            if g != a { out.append("\(path): \(g.prefix(80)) vs \(a.prefix(80))") }
        default:
            out.append("\(path): type mismatch \(type(of: golden)) vs \(type(of: actual))")
        }
    }

    static func expectEqual(_ golden: Any, _ actual: Any, _ name: String) throws {
        // Round-trip through JSON so Swift Int/Double/Bool land as NSNumber.
        let a = try JSONSerialization.jsonObject(
            with: JSONSerialization.data(withJSONObject: actual))
        var diffs: [String] = []
        diff(golden, a, into: &diffs)
        #expect(diffs.isEmpty, "\(name): \(diffs.prefix(10).joined(separator: "\n"))")
    }
}

@Suite(.enabled(if: Goldens.root != nil, "lgka-app/verification checkout not found"))
struct GoldenParityTests {
    @Test func substitutionPlans() throws {
        let names = try Goldens.list("goldens/substitution", suffix: ".v2.json")
        #expect(!names.isEmpty)
        for name in names {
            let g = try Goldens.golden("goldens/substitution/\(name)")
            let input = try #require(g["input"] as? [String: Any])
            let pdf = try Goldens.file(try #require(input["file"] as? String))
            let plan = try Extractor.extract(lines: extractLines(from: pdf))
            try Goldens.expectEqual(try #require(g["expected"]), plan, name)
        }
    }

    @Test func classIndexes() throws {
        let names = try Goldens.list("goldens/schedule", suffix: ".json", prefix: "class_index_")
        #expect(!names.isEmpty)
        for name in names {
            let g = try Goldens.golden("goldens/schedule/\(name)")
            let input = try #require(g["input"] as? [String: Any])
            let pdf = try Goldens.file(try #require(input["file"] as? String))
            let index = try buildClassIndex(url: pdf)
            try Goldens.expectEqual(try #require(g["expected"]), ["classIndex5to10": index], name)
        }
    }

    @Test func schedulePage() throws {
        let names = try Goldens.list("goldens/schedule", suffix: ".json", prefix: "stundenplan_page_")
        #expect(!names.isEmpty)
        for name in names {
            let g = try Goldens.golden("goldens/schedule/\(name)")
            let input = try #require(g["input"] as? [String: Any])
            let html = try Goldens.text(try #require(input["file"] as? String))
            try Goldens.expectEqual(try #require(g["expected"]), try ScheduleHtmlParser.parse(html), name)
        }
    }

    @Test func news() throws {
        let names = try Goldens.list("goldens/news", suffix: ".json", prefix: "news_")
        #expect(!names.isEmpty)
        for name in names {
            let g = try Goldens.golden("goldens/news/\(name)")
            let input = try #require(g["input"] as? [String: Any])
            let manifestPath = try #require(input["manifest"] as? String)
            let manifest = try Goldens.golden(manifestPath)
            let dir = (manifestPath as NSString).deletingLastPathComponent
            var urlToFile: [String: String] = [:]
            for a in manifest["articles"] as? [[String: String]] ?? [] {
                if let u = a["url"], let f = a["file"] { urlToFile[u] = f }
            }
            let listHtml = try Goldens.text("\(dir)/\(try #require(manifest["listFile"] as? String))")
            let result = try NewsParser.run(listHtml: listHtml, urlToFile: urlToFile) {
                try Goldens.text("\(dir)/\($0)")
            }
            try Goldens.expectEqual(try #require(g["expected"]), result, name)
        }
    }

    @Test func events() throws {
        let names = try Goldens.list("goldens/events", suffix: ".json", prefix: "events_")
        #expect(!names.isEmpty)
        for name in names {
            let g = try Goldens.golden("goldens/events/\(name)")
            let input = try #require(g["input"] as? [String: Any])
            let params = try #require(g["params"] as? [String: Any])
            let manifestPath = try #require(input["manifest"] as? String)
            let manifest = try Goldens.golden(manifestPath)
            let dir = (manifestPath as NSString).deletingLastPathComponent
            let htmls = try (manifest["weeks"] as? [[String: String]] ?? [])
                .compactMap { $0["file"] }.map { try Goldens.text("\(dir)/\($0)") }
            let today = try #require(params["today"] as? String)
            let result = EventsParser.aggregate(weekHtmls: htmls, today: today)
            try Goldens.expectEqual(try #require(g["expected"]), result, name)
        }
    }

    @Test func weather() throws {
        let names = try Goldens.list("goldens/weather", suffix: ".json", prefix: "weather_")
        #expect(!names.isEmpty)
        for name in names {
            let g = try Goldens.golden("goldens/weather/\(name)")
            let input = try #require(g["input"] as? [String: Any])
            let params = try #require(g["params"] as? [String: Any])
            let json = try Goldens.text(try #require(input["file"] as? String))
            let refNow = try #require(params["referenceNow"] as? String)
            let result = try WeatherParser.parse(json, referenceNow: refNow)
            try Goldens.expectEqual(try #require(g["expected"]), result, name)
        }
    }
}
