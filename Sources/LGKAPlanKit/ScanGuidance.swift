import Foundation

/// A point in a camera frame, 0…1, origin top-left.
public struct ScanPoint: Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    func distance(to other: ScanPoint) -> Double { hypot(x - other.x, y - other.y) }
}

/// The detected sheet: four corners in reading order.
public struct ScanQuad: Sendable, Hashable {
    public var topLeft: ScanPoint
    public var topRight: ScanPoint
    public var bottomRight: ScanPoint
    public var bottomLeft: ScanPoint

    public init(topLeft: ScanPoint, topRight: ScanPoint, bottomRight: ScanPoint, bottomLeft: ScanPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    public var corners: [ScanPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    /// Share of the frame the sheet covers (shoelace formula).
    public var area: Double {
        let c = corners
        var sum = 0.0
        for i in c.indices {
            let a = c[i], b = c[(i + 1) % c.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    /// Shorter over longer of each pair of opposite sides; 1 for a sheet seen straight on.
    public var squareness: Double {
        let top = topLeft.distance(to: topRight), bottom = bottomLeft.distance(to: bottomRight)
        let left = topLeft.distance(to: bottomLeft), right = topRight.distance(to: bottomRight)
        guard max(top, bottom) > 0, max(left, right) > 0 else { return 0 }
        return min(min(top, bottom) / max(top, bottom), min(left, right) / max(left, right))
    }

    /// A corner lies on (or past) the frame edge: the sheet is cut off.
    public func touchesEdge(margin: Double) -> Bool {
        corners.contains { $0.x < margin || $0.y < margin || $0.x > 1 - margin || $0.y > 1 - margin }
    }

    /// Largest corner movement from another detection.
    public func jitter(from other: ScanQuad) -> Double {
        zip(corners, other.corners).map { $0.distance(to: $1) }.max() ?? 0
    }
}

/// One analysed camera frame.
public struct ScanFrame: Sendable, Hashable {
    public var quad: ScanQuad?
    /// Mean brightness 0…1 (inside the sheet when one is found).
    public var luma: Double
    /// Share of clipped, near-white pixels on the sheet.
    public var glare: Double
    /// Angle between the phone's back and straight down, degrees.
    public var tilt: Double
    /// Rotation rate plus user acceleration.
    public var motion: Double
    /// Corner movement since the previous frame (0…1 of the frame).
    public var jitter: Double
    /// Seconds, monotonic.
    public var time: Double

    public init(quad: ScanQuad?, luma: Double, glare: Double, tilt: Double, motion: Double, jitter: Double, time: Double) {
        self.quad = quad
        self.luma = luma
        self.glare = glare
        self.tilt = tilt
        self.motion = motion
        self.jitter = jitter
        self.time = time
    }
}

/// What the user should do next, most important first.
public enum ScanHint: String, Sendable, CaseIterable {
    case noDocument, tooDark, moveCloser, moveBack, holdParallel, glare, holdStill, ready
}

/// Turns analysed frames into one calm instruction and decides when to take the photo.
///
/// Thresholds come from what the Kurswahlprotokoll needs to be readable: the bracketed course
/// numbers are ~2 mm tall, so the sheet has to fill ≥ 40 % of the frame; a tilt beyond ~12°
/// makes the table rows slope; a few percent of clipped white hides whole cells.
public struct ScanGuidance: Sendable {
    public static let minLuma = 0.22
    /// Half the frame: at A4 that puts the ~2 mm course numbers at a size text recognition reads reliably.
    public static let minArea = 0.50
    public static let edgeMargin = 0.012
    public static let maxTilt = 12.0
    public static let minSquareness = 0.72
    public static let maxGlare = 0.04
    public static let maxMotion = 0.35
    public static let maxJitter = 0.02
    /// How long "ready" has to hold before the photo is taken.
    public static let readyDuration = 0.8
    /// How long a new hint has to hold before it replaces the shown one (no flicker).
    public static let hintDelay = 0.3

    public struct State: Sendable, Hashable {
        /// The instruction to show.
        public var hint: ScanHint
        /// 0…1 while "ready" stabilises.
        public var progress: Double
        /// True exactly once, when "ready" has held long enough.
        public var capture: Bool

        public init(hint: ScanHint, progress: Double, capture: Bool) {
            self.hint = hint
            self.progress = progress
            self.capture = capture
        }
    }

    private var shown: ScanHint = .noDocument
    private var pending: ScanHint?
    private var pendingSince = 0.0
    private var readySince: Double?
    private var fired = false

    public init() {}

    /// The instruction for a single frame, without any smoothing.
    public static func hint(for frame: ScanFrame) -> ScanHint {
        guard let quad = frame.quad else { return frame.luma < minLuma ? .tooDark : .noDocument }
        if frame.luma < minLuma { return .tooDark }
        if quad.touchesEdge(margin: edgeMargin) { return .moveBack }
        if quad.area < minArea { return .moveCloser }
        if frame.tilt > maxTilt || quad.squareness < minSquareness { return .holdParallel }
        if frame.glare > maxGlare { return .glare }
        if frame.motion > maxMotion || frame.jitter > maxJitter { return .holdStill }
        return .ready
    }

    public mutating func update(_ frame: ScanFrame) -> State {
        let raw = Self.hint(for: frame)

        // "ready" is never delayed (the progress ring shows it), other hints wait a moment
        if raw == shown || raw == .ready || shown == .ready {
            shown = raw
            pending = nil
        } else if pending != raw {
            pending = raw
            pendingSince = frame.time
        } else if frame.time - pendingSince >= Self.hintDelay {
            shown = raw
            pending = nil
        }

        guard raw == .ready else {
            readySince = nil
            fired = false
            return State(hint: shown, progress: 0, capture: false)
        }
        let since = readySince ?? frame.time
        readySince = since
        let progress = min(1, (frame.time - since) / Self.readyDuration)
        let capture = progress >= 1 && !fired
        if capture { fired = true }
        return State(hint: .ready, progress: progress, capture: capture)
    }

    /// Starts over, e.g. after a photo was taken.
    public mutating func reset() {
        self = ScanGuidance()
    }
}
