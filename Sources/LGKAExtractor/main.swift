import Foundation

// Runner: `<substitution|classindex> <fixturesDir> <outDir>`
//  - substitution: every *.pdf -> <name>.json (full plan extraction)
//  - classindex:   every *.pdf -> class_index_<name>.json (schedule index)
let args = CommandLine.arguments
guard args.count == 4, ["substitution", "classindex"].contains(args[1]) else {
    FileHandle.standardError.write(
        "usage: lgka-extractor <substitution|classindex> <fixturesDir> <outDir>\n"
            .data(using: .utf8)!)
    exit(1)
}
let mode = args[1]
let fixturesDir = URL(fileURLWithPath: args[2])
let outDir = URL(fileURLWithPath: args[3])
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
    let name: String
    let result: [String: Any]
    let base = pdf.deletingPathExtension().lastPathComponent
    switch mode {
    case "substitution":
        name = base
        if let lines = extractLines(from: pdf) {
            result = Extractor.extract(lines: lines)
        } else {
            result = ["error": "failed to load PDF or page 0"]
        }
    default: // classindex
        name = "class_index_\(base)"
        if let index = buildClassIndex(url: pdf) {
            result = ["classIndex5to10": index]
        } else {
            result = ["error": "failed to load PDF"]
        }
    }
    let data = try JSONSerialization.data(
        withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: outDir.appendingPathComponent(name + ".json"))
    print("wrote \(name).json")
}
