import Foundation
import LGKACore

// Runner: `<mode> <fixturesDir> <outDir> [extra]`
//  - substitution: every *.pdf -> <name>.json (full plan extraction)
//  - classindex:   every *.pdf -> class_index_<name>.json (schedule index)
//  - schedulehtml: every *.html -> <name>.json
//  - news:         every manifest_*.json -> news_<stamp>.json
//  - events:       every manifest_*.json -> events_<stamp>.json
//  - weather:      every openmeteo_*.json -> weather_<stamp>.json
//                  (extra arg = referenceNow ISO from the golden params)
let args = CommandLine.arguments
let modes = ["substitution", "classindex", "schedulehtml", "news", "events", "weather"]
guard args.count >= 4, modes.contains(args[1]) else {
    FileHandle.standardError.write(
        Data("usage: lgka-extractor <mode> <fixturesDir> <outDir> [referenceNow]\n".utf8))
    exit(1)
}
let mode = args[1]
let fixturesDir = URL(fileURLWithPath: args[2])
let outDir = URL(fileURLWithPath: args[3])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func files(_ ext: String, prefix: String = "") -> [URL] {
    (try? FileManager.default.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil))?
        .filter { $0.pathExtension == ext && ($0.lastPathComponent.hasPrefix(prefix) || prefix.isEmpty) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
}

func write(_ name: String, _ result: Any) throws {
    let data = try JSONSerialization.data(
        withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: outDir.appendingPathComponent(name + ".json"))
    print("wrote \(name).json")
}

func readManifest(_ url: URL) throws -> [String: Any] {
    guard let m = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    else { throw LGKAError.invalidJSON(url.lastPathComponent) }
    return m
}

func stamp(_ manifest: URL) -> String {
    manifest.deletingPathExtension().lastPathComponent
        .replacingOccurrences(of: "manifest_", with: "")
}

let pdfs = files("pdf")
if ProcessInfo.processInfo.environment["DUMP_RAW"] != nil, let first = pdfs.first {
    import_dump_raw(url: first)
    exit(0)
}
if ProcessInfo.processInfo.environment["DUMP_LINES"] != nil, let first = pdfs.first {
    for line in (try? extractLines(from: first)) ?? [] {
        let words = line.words.map { "\($0.text)@\(Int($0.left))-\(Int($0.right))" }
        print("y=\(String(format: "%.1f", line.top)) \(words.joined(separator: " | "))")
    }
    exit(0)
}

switch mode {
case "substitution":
    for pdf in pdfs {
        let name = pdf.deletingPathExtension().lastPathComponent
        do {
            try write(name, Extractor.extract(lines: extractLines(from: pdf)))
        } catch {
            try write(name, ["error": "\(error)"])
        }
    }
case "classindex":
    for pdf in pdfs {
        let name = "class_index_\(pdf.deletingPathExtension().lastPathComponent)"
        do {
            try write(name, ["classIndex5to10": buildClassIndex(url: pdf)])
        } catch {
            try write(name, ["error": "\(error)"])
        }
    }
case "schedulehtml":
    for page in files("html") {
        let name = page.deletingPathExtension().lastPathComponent
        let html = try String(contentsOf: page, encoding: .utf8)
        try write(name, ScheduleHtmlParser.parse(html))
    }
case "news":
    for mf in files("json", prefix: "manifest_") {
        let m = try readManifest(mf)
        var urlToFile: [String: String] = [:]
        for a in m["articles"] as? [[String: String]] ?? [] {
            if let u = a["url"], let f = a["file"] { urlToFile[u] = f }
        }
        guard let listFile = m["listFile"] as? String else {
            throw LGKAError.missingField("listFile")
        }
        let listHtml = try String(
            contentsOf: fixturesDir.appendingPathComponent(listFile), encoding: .utf8)
        let result = try NewsParser.run(listHtml: listHtml, urlToFile: urlToFile) { name in
            try String(contentsOf: fixturesDir.appendingPathComponent(name), encoding: .utf8)
        }
        try write("news_\(stamp(mf))", result)
    }
case "events":
    for mf in files("json", prefix: "manifest_") {
        let m = try readManifest(mf)
        guard let today = m["today"] as? String else { throw LGKAError.missingField("today") }
        let htmls = try (m["weeks"] as? [[String: String]] ?? []).compactMap { $0["file"] }.map {
            try String(contentsOf: fixturesDir.appendingPathComponent($0), encoding: .utf8)
        }
        try write("events_\(stamp(mf))", EventsParser.aggregate(weekHtmls: htmls, today: today))
    }
default: // weather
    guard args.count == 5 else {
        FileHandle.standardError.write(Data("weather mode needs <referenceNow>\n".utf8))
        exit(1)
    }
    for snap in files("json", prefix: "openmeteo_") {
        let name = "weather_" + snap.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "openmeteo_", with: "")
        let text = try String(contentsOf: snap, encoding: .utf8)
        try write(name, try WeatherParser.parse(text, referenceNow: args[4]))
    }
}
