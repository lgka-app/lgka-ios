import Foundation
import Testing
@testable import LGKACore

/// Live scanning: frames of a moving phone, already mapped to sheet coordinates. The fixture's
/// boxes stand in for the sheet; each "frame" sees only part of it.
@Suite("Live sheet scan")
struct SheetScanTests {
    static func sheet() throws -> [TextBox] {
        try JSONDecoder().decode([TextBox].self, from: Fixtures.data("kurswahl_ocr"))
    }

    @Test func framesAddUpToACompleteSheet() throws {
        let boxes = try Self.sheet()
        var scan = SheetScanAccumulator(aspect: 4.0 / 3.0)
        #expect(scan.progress(schuljahr: "2026-2027", halbjahr: "1. Halbjahr").rows == 0)

        scan.add(boxes.filter { $0.y < 0.5 }, quality: 1)
        let upper = scan.progress(schuljahr: "2026-2027", halbjahr: "1. Halbjahr")
        #expect(!upper.complete)
        #expect(upper.sum == nil)
        #expect(upper.hours > 0)

        scan.add(boxes.filter { $0.y > 0.4 }, quality: 0.8)
        let whole = scan.progress(schuljahr: "2026-2027", halbjahr: "1. Halbjahr")
        #expect(whole.complete)
        #expect(whole.hours == 34 && whole.sum == 34)
        #expect(whole.subjects == 20)
        #expect(whole.marks.contains { $0.kind == .sum && $0.text == "34" })
        #expect(whole.marks.contains { $0.kind == .value && $0.text == "5(3)" })
    }

    @Test func frequentReadingOutvotesAMisread() {
        var scan = SheetScanAccumulator()
        let right = TextBox(text: "2", x: 0.5, y: 0.5, width: 0.01, height: 0.01, confidence: 0.9)
        var wrong = right
        wrong.text = "-"
        wrong.x += 0.002
        scan.add([wrong])
        scan.add([right])
        scan.add([right], quality: 0.6)
        #expect(scan.boxes.map(\.text) == ["2"])
    }

    @Test func sheetScannedTwiceGivesTheSamePlan() throws {
        let boxes = try Self.sheet()
        var scan = SheetScanAccumulator(aspect: 4.0 / 3.0)
        scan.add(boxes)
        scan.add(boxes, quality: 0.5)
        let progress = scan.progress(schuljahr: "2026-2027", halbjahr: "1. Halbjahr")
        #expect(progress.complete)
        #expect(progress.kurswahl?.rows.first { $0.subject == "D" }?.halves.first?.parallel == 3)
    }
}
