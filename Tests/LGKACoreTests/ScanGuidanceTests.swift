import Foundation
import Testing
import LGKACore
@testable import LGKAPlanKit

@Suite("Scan guidance")
struct ScanGuidanceTests {
    /// A straight-on sheet covering ~56 % of the frame.
    static let good = ScanQuad(topLeft: .init(x: 0.12, y: 0.12), topRight: .init(x: 0.88, y: 0.12),
                               bottomRight: .init(x: 0.88, y: 0.86), bottomLeft: .init(x: 0.12, y: 0.86))

    static func frame(quad: ScanQuad? = good, luma: Double = 0.6, glare: Double = 0, tilt: Double = 3,
                      motion: Double = 0.05, jitter: Double = 0.002, time: Double = 0) -> ScanFrame {
        ScanFrame(quad: quad, luma: luma, glare: glare, tilt: tilt, motion: motion, jitter: jitter, time: time)
    }

    @Test func geometry() {
        #expect(abs(Self.good.area - 0.5624) < 0.001)
        #expect(Self.good.squareness == 1)
        #expect(!Self.good.touchesEdge(margin: ScanGuidance.edgeMargin))
        let cut = ScanQuad(topLeft: .init(x: 0, y: 0.1), topRight: .init(x: 0.9, y: 0.1),
                           bottomRight: .init(x: 0.9, y: 0.9), bottomLeft: .init(x: 0, y: 0.9))
        #expect(cut.touchesEdge(margin: ScanGuidance.edgeMargin))
    }

    @Test func eachHintInPriorityOrder() {
        #expect(ScanGuidance.hint(for: Self.frame(quad: nil)) == .noDocument)
        #expect(ScanGuidance.hint(for: Self.frame(quad: nil, luma: 0.1)) == .tooDark)
        // darkness wins over everything else that is wrong
        #expect(ScanGuidance.hint(for: Self.frame(luma: 0.1, glare: 0.5, tilt: 40, motion: 3)) == .tooDark)

        let small = ScanQuad(topLeft: .init(x: 0.3, y: 0.3), topRight: .init(x: 0.7, y: 0.3),
                             bottomRight: .init(x: 0.7, y: 0.7), bottomLeft: .init(x: 0.3, y: 0.7))
        #expect(ScanGuidance.hint(for: Self.frame(quad: small, tilt: 40)) == .moveCloser)

        let cut = ScanQuad(topLeft: .init(x: 0.005, y: 0.1), topRight: .init(x: 0.9, y: 0.1),
                           bottomRight: .init(x: 0.9, y: 0.9), bottomLeft: .init(x: 0.005, y: 0.9))
        #expect(ScanGuidance.hint(for: Self.frame(quad: cut, tilt: 40)) == .moveBack)

        #expect(ScanGuidance.hint(for: Self.frame(glare: 0.5, tilt: 20)) == .holdParallel)
        let trapezoid = ScanQuad(topLeft: .init(x: 0.3, y: 0.1), topRight: .init(x: 0.7, y: 0.1),
                                 bottomRight: .init(x: 0.95, y: 0.9), bottomLeft: .init(x: 0.05, y: 0.9))
        #expect(ScanGuidance.hint(for: Self.frame(quad: trapezoid)) == .holdParallel)

        #expect(ScanGuidance.hint(for: Self.frame(glare: 0.1, motion: 3)) == .glare)
        #expect(ScanGuidance.hint(for: Self.frame(motion: 1)) == .holdStill)
        #expect(ScanGuidance.hint(for: Self.frame(jitter: 0.05)) == .holdStill)
        #expect(ScanGuidance.hint(for: Self.frame()) == .ready)
    }

    @Test func thresholdsAreInclusiveOfGoodValues() {
        #expect(ScanGuidance.hint(for: Self.frame(luma: ScanGuidance.minLuma)) == .ready)
        #expect(ScanGuidance.hint(for: Self.frame(tilt: ScanGuidance.maxTilt)) == .ready)
        #expect(ScanGuidance.hint(for: Self.frame(glare: ScanGuidance.maxGlare)) == .ready)
        #expect(ScanGuidance.hint(for: Self.frame(motion: ScanGuidance.maxMotion)) == .ready)
    }

    @Test func captureFiresOnceAfterReadyHolds() {
        var guidance = ScanGuidance()
        var captures = 0
        var lastProgress = 0.0
        for step in 0...12 {
            let state = guidance.update(Self.frame(time: Double(step) * 0.1))
            #expect(state.hint == .ready)
            #expect(state.progress >= lastProgress)
            lastProgress = state.progress
            if state.capture {
                captures += 1
                #expect(Double(step) * 0.1 >= ScanGuidance.readyDuration - 1e-9)
            }
        }
        #expect(captures == 1)
        #expect(lastProgress == 1)
    }

    @Test func movementRestartsTheTimer() {
        var guidance = ScanGuidance()
        _ = guidance.update(Self.frame(time: 0))
        #expect(guidance.update(Self.frame(time: 0.6)).progress > 0.7)
        let shaken = guidance.update(Self.frame(motion: 2, time: 0.7))
        #expect(shaken.progress == 0)
        #expect(!shaken.capture)
        #expect(guidance.update(Self.frame(time: 0.8)).progress == 0)
        #expect(!guidance.update(Self.frame(time: 1.5)).capture)
        #expect(guidance.update(Self.frame(time: 1.7)).capture)
    }

    @Test func hintsDoNotFlicker() {
        var guidance = ScanGuidance()
        #expect(guidance.update(Self.frame(quad: nil, time: 0)).hint == .noDocument)
        // a single dark frame does not replace the shown hint
        #expect(guidance.update(Self.frame(quad: nil, luma: 0.1, time: 0.1)).hint == .noDocument)
        #expect(guidance.update(Self.frame(quad: nil, time: 0.2)).hint == .noDocument)
        // a lasting one does
        _ = guidance.update(Self.frame(quad: nil, luma: 0.1, time: 0.3))
        #expect(guidance.update(Self.frame(quad: nil, luma: 0.1, time: 0.5)).hint == .noDocument)
        #expect(guidance.update(Self.frame(quad: nil, luma: 0.1, time: 0.65)).hint == .tooDark)
        // ready shows straight away
        #expect(guidance.update(Self.frame(time: 0.7)).hint == .ready)
    }

    @Test func resetStartsOver() {
        var guidance = ScanGuidance()
        for step in 0...9 { _ = guidance.update(Self.frame(time: Double(step) * 0.1)) }
        guidance.reset()
        let state = guidance.update(Self.frame(time: 2))
        #expect(state.progress == 0)
        #expect(!state.capture)
    }

    // MARK: Structure trackers (recognised text of a real Kurswahlprotokoll photo)

    static func sheetBoxes() throws -> [TextBox] {
        try JSONDecoder().decode([TextBox].self, from: Fixtures.data("kurswahl_ocr"))
    }

    /// The boxes a close-up of one vertical band of the sheet would see, rescaled to that frame.
    static func closeUp(_ boxes: [TextBox], _ band: ClosedRange<Double>) -> [TextBox] {
        let span = band.upperBound - band.lowerBound
        return boxes.filter { band.contains($0.midY) }.map { box in
            var b = box
            b.y = (box.y - band.lowerBound) / span
            b.height = box.height / span
            return b
        }
    }

    @Test func wholeSheetSatisfiesTheOverviewOnly() throws {
        let structure = ShotStructure.analyse(try Self.sheetBoxes())
        #expect(structure.titleSeen)
        #expect(structure.summenSeen)
        #expect(structure.subjects.count >= ShotStructure.minOverviewSubjects)
        #expect(structure.missing(for: .overview) == nil)
        // the same text is too small for the close-up steps
        #expect(structure.lineHeight < ShotStructure.minLineHeight)
        #expect(structure.missing(for: .tableTop) == .moveCloser)
        #expect(structure.missing(for: .tableBottom) == .moveCloser)
    }

    @Test func closeUpsOfTheTableHalves() throws {
        let boxes = try Self.sheetBoxes()
        let top = ShotStructure.analyse(Self.closeUp(boxes, 0.30...0.66))
        #expect(top.headerSeen)
        #expect(top.lineHeight >= ShotStructure.minLineHeight)
        #expect(top.missing(for: .tableTop) == nil)
        #expect(top.missing(for: .tableBottom) == .frameTableBottom)
        #expect(top.missing(for: .overview) == .wholeSheet)

        let bottom = ShotStructure.analyse(Self.closeUp(boxes, 0.62...0.93))
        #expect(bottom.summenSeen)
        #expect(bottom.sumNumbers >= ShotStructure.minSumNumbers)
        #expect(bottom.summenLine.count == 2)
        #expect(bottom.missing(for: .tableBottom) == nil)
        #expect(bottom.missing(for: .tableTop) == .frameTableTop)
    }

    @Test func stepHints() throws {
        let boxes = try Self.sheetBoxes()
        let sheet = ShotStructure.analyse(boxes)
        let top = ShotStructure.analyse(Self.closeUp(boxes, 0.30...0.66))

        // overview: sheet checks first, then the structure
        #expect(ScanGuidance.hint(for: Self.frame(quad: nil), shot: .overview, structure: sheet) == .noDocument)
        #expect(ScanGuidance.hint(for: Self.frame(), shot: .overview, structure: nil) == .wholeSheet)
        #expect(ScanGuidance.hint(for: Self.frame(motion: 1), shot: .overview, structure: .empty) == .wholeSheet)
        #expect(ScanGuidance.hint(for: Self.frame(), shot: .overview, structure: sheet) == .ready)

        // close-ups: a cut sheet is fine, no "move back", no outline needed
        let cut = ScanQuad(topLeft: .init(x: -0.1, y: -0.2), topRight: .init(x: 1.1, y: -0.2),
                           bottomRight: .init(x: 1.1, y: 1.2), bottomLeft: .init(x: -0.1, y: 1.2))
        #expect(ScanGuidance.hint(for: Self.frame(quad: cut, jitter: 0.3), shot: .tableTop, structure: top) == .ready)
        #expect(ScanGuidance.hint(for: Self.frame(quad: nil), shot: .tableTop, structure: top) == .ready)
        #expect(ScanGuidance.hint(for: Self.frame(quad: nil), shot: .tableTop, structure: nil) == .frameTableTop)
        #expect(ScanGuidance.hint(for: Self.frame(quad: nil), shot: .tableTop, structure: sheet) == .moveCloser)
        #expect(ScanGuidance.hint(for: Self.frame(quad: nil, luma: 0.1), shot: .tableTop, structure: top) == .tooDark)
        #expect(ScanGuidance.hint(for: Self.frame(quad: nil, tilt: 20), shot: .tableTop, structure: top) == .holdParallel)
        #expect(ScanGuidance.hint(for: Self.frame(quad: nil, motion: 1), shot: .tableTop, structure: top) == .holdStill)
        #expect(ScanGuidance.hint(for: Self.frame(quad: nil), shot: .tableBottom, structure: top) == .frameTableBottom)
    }

    @Test func closeUpCapturesOnceTheStructureHolds() throws {
        let top = ShotStructure.analyse(Self.closeUp(try Self.sheetBoxes(), 0.30...0.66))
        var guidance = ScanGuidance()
        #expect(guidance.update(Self.frame(quad: nil, time: 0), shot: .tableTop, structure: nil).progress == 0)
        var captured = false
        for step in 1...10 {
            captured = captured || guidance.update(Self.frame(quad: nil, time: Double(step) * 0.1), shot: .tableTop, structure: top).capture
        }
        #expect(captured)
    }
}
