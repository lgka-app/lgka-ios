import Foundation

// Runner: `<fixturesDir> <outDir>` — extracts every *.pdf into JSON.
let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: lgka-extractor <fixturesDir> <outDir>\n".data(using: .utf8)!)
    exit(1)
}
let fixturesDir = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let pdfs = try FileManager.default.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "pdf" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

if ProcessInfo.processInfo.environment["DUMP_RAW"] != nil, let first = pdfs.first {
    import_dump_raw(url: first)
    exit(0)
}

if ProcessInfo.processInfo.environment["DUMP_LINES"] != nil, let first = pdfs.first {
    for line in extractLines(from: first) ?? [] {
        let words = line.words.map { "\($0.text)@\(Int($0.left))-\(Int($0.right))" }
        print("y=\(String(format: "%.1f", line.top)) \(words.joined(separator: " | "))")
    }
    exit(0)
}

for pdf in pdfs {
    let result: [String: Any]
    if let lines = extractLines(from: pdf) {
        result = Extractor.extract(lines: lines)
    } else {
        result = ["error": "failed to load PDF or page 0"]
    }
    let data = try JSONSerialization.data(
        withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    let name = pdf.deletingPathExtension().lastPathComponent + ".json"
    try data.write(to: outDir.appendingPathComponent(name))
    print("wrote \(name)")
}
