import Foundation

import Testing
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

    @Test func torchLightsTheSheetEnough() {
        let dim = ScanGuidance.minLuma * 0.85
        #expect(ScanGuidance.hint(for: ScanFrame(quad: Self.good, luma: dim, glare: 0, tilt: 3, motion: 0.05, jitter: 0.002, time: 0)) == .tooDark)
        #expect(ScanGuidance.hint(for: ScanFrame(quad: Self.good, luma: dim, glare: 0, tilt: 3, motion: 0.05, jitter: 0.002, time: 0,
                                                 torch: 0.5)) == .ready)
        #expect(ScanGuidance.hint(for: ScanFrame(quad: Self.good, luma: 0.05, glare: 0, tilt: 3, motion: 0.05, jitter: 0.002, time: 0,
                                                 torch: 1)) == .tooDark)
    }

    @Test func torchComesOnAfterAMomentOfDarkness() {
        var torch = TorchPolicy()
        #expect(torch.update(luma: 0.1, glare: 0, time: 0) == 0)
        #expect(torch.update(luma: 0.1, glare: 0, time: 0.3) == 0)
        // a bright frame in between starts the wait over
        #expect(torch.update(luma: 0.6, glare: 0, time: 0.4) == 0)
        #expect(torch.update(luma: 0.1, glare: 0, time: 0.5) == 0)
        #expect(torch.update(luma: 0.1, glare: 0, time: 0.9) == 0)
        #expect(torch.update(luma: 0.1, glare: 0, time: 1.0) == TorchPolicy.startLevel)
    }

    @Test func torchStaysOnAndAdjusts() {
        var torch = TorchPolicy()
        _ = torch.update(luma: 0.1, glare: 0, time: 0)
        _ = torch.update(luma: 0.1, glare: 0, time: 0.5)
        #expect(torch.isOn)
        // still too dark: brighter, but only after the exposure had time to settle
        #expect(torch.update(luma: 0.1, glare: 0, time: 0.8) == TorchPolicy.startLevel)
        #expect(torch.update(luma: 0.1, glare: 0, time: 1.2) == 0.75)
        // bright now: stays on, no flicker
        #expect(torch.update(luma: 0.7, glare: 0, time: 5) == 0.75)
        // glare on the paper: dimmer, never off
        #expect(abs(torch.update(luma: 0.7, glare: 0.2, time: 6) - 0.55) < 1e-9)
        for step in 1...10 { _ = torch.update(luma: 0.7, glare: 0.2, time: 6 + Double(step)) }
        #expect(torch.level == TorchPolicy.minLevel)
    }

    @Test func resetStartsOver() {
        var guidance = ScanGuidance()
        for step in 0...9 { _ = guidance.update(Self.frame(time: Double(step) * 0.1)) }
        guidance.reset()
        let state = guidance.update(Self.frame(time: 2))
        #expect(state.progress == 0)
        #expect(!state.capture)
    }
}

/// The scanner keeps the torch on from the first frame, in any light; glare still dims it.
@Test func alwaysOnTorchStartsImmediately() {
    var torch = TorchPolicy(alwaysOn: true)
    #expect(torch.update(luma: 0.9, glare: 0, time: 0) == TorchPolicy.startLevel)
    #expect(torch.isOn)
    #expect(torch.update(luma: 0.9, glare: 0.2, time: 1) < TorchPolicy.startLevel)
    #expect(torch.isOn)
}
