import Foundation
import LGKACore

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
    /// Overview step: the title, the table and the "Summen" row are not all visible yet.
    case wholeSheet
    /// Close-up of the table's upper half is not framed yet.
    case frameTableTop
    /// Close-up of the table's lower half down to "Summen" is not framed yet.
    case frameTableBottom
}

/// The three photos of a Kurswahlprotokoll: the whole sheet for name, year and sums, then two
/// close-ups of the table so the small bracketed course numbers are large enough to read.
public enum KurswahlShot: Int, CaseIterable, Sendable {
    case overview     // whole sheet: name, Abiturjahr, Konfession, table, Summen row
    case tableTop     // close-up: table header ("Fächer", "pro Kurs", "1. Hj") and rows D … Ch
    case tableBottom  // close-up: rows from about Ch / Sport down to "Summen"

    /// Only the whole-sheet photo needs the sheet outline; close-ups cut the sheet on purpose.
    public var needsSheet: Bool { self == .overview }

    /// The part of an A4 portrait sheet this photo frames (0…1 from the top), for the step diagram.
    public var region: ClosedRange<Double> {
        switch self {
        case .overview: 0...1
        case .tableTop: 0.28...0.64
        case .tableBottom: 0.58...0.92
        }
    }
}

/// What fast text recognition on a preview frame found of the Kurswahlprotokoll's structure.
///
/// Anchors come from the printed form: the title or "Abiturjahr" at the top, the table header
/// ("Fächer", "Fachart", "pro Kurs"), the subject abbreviations lined up in the Fächer column,
/// cell values like "5(3)" right of it, and the "Summen" row with its two-digit sums.
public struct ShotStructure: Sendable, Hashable {
    public var titleSeen: Bool
    public var headerSeen: Bool
    public var summenSeen: Bool
    /// Subject keys found in the Fächer column.
    public var subjects: Set<String>
    /// Cell values ("5(3)", "2", "-") right of the Fächer column.
    public var cellValues: Int
    /// Two-digit numbers on the "Summen" row.
    public var sumNumbers: Int
    /// Median height of the short table tokens, 0…1 of the frame height (0 when none).
    public var lineHeight: Double
    /// Where the subject keys sit, for the live markers.
    public var subjectPoints: [ScanPoint]
    /// Start and end of the "Summen" row (empty when not seen).
    public var summenLine: [ScanPoint]
    /// The table header.
    public var header: ScanPoint?

    public init(titleSeen: Bool, headerSeen: Bool, summenSeen: Bool, subjects: Set<String>, cellValues: Int,
                sumNumbers: Int, lineHeight: Double, subjectPoints: [ScanPoint], summenLine: [ScanPoint], header: ScanPoint?) {
        self.titleSeen = titleSeen
        self.headerSeen = headerSeen
        self.summenSeen = summenSeen
        self.subjects = subjects
        self.cellValues = cellValues
        self.sumNumbers = sumNumbers
        self.lineHeight = lineHeight
        self.subjectPoints = subjectPoints
        self.summenLine = summenLine
        self.header = header
    }

    public static let empty = ShotStructure(titleSeen: false, headerSeen: false, summenSeen: false, subjects: [],
                                            cellValues: 0, sumNumbers: 0, lineHeight: 0, subjectPoints: [],
                                            summenLine: [], header: nil)

    /// Rows of the upper table half and of the lower one.
    public static let upperSubjects: Set<String> = ["D", "E", "F", "Sp", "BK", "Mu", "G", "Gk", "Geo", "Rel", "Eth", "M", "Bio", "Ph", "Ch"]
    public static let lowerSubjects: Set<String> = ["Ch", "Sport", "Inf", "Psy", "Ast", "LTh"]

    /// The whole sheet shows most subjects even with small text.
    public static let minOverviewSubjects = 8
    public static let minTopSubjects = 6
    public static let minTopCells = 3
    public static let minBottomSubjects = 3
    public static let minSumNumbers = 2
    /// A close-up is only worth it when the table text is clearly larger than on the whole-sheet
    /// photo (~1.2 % of the frame there): at ≥ 1.8 % the 2 mm course numbers read reliably.
    public static let minLineHeight = 0.018

    /// Reads the structure from recognised text (boxes 0…1 of the frame, origin top-left).
    public static func analyse(_ boxes: [TextBox]) -> ShotStructure {
        let words = boxes.flatMap { $0.words() }
        let keys = SchoolReference.subjects.map(\.key)
        let subjectWords: [(key: String, box: TextBox)] = words.compactMap { word in
            let text = word.text.trimmingCharacters(in: .punctuationCharacters)
            return keys.first { $0.caseInsensitiveCompare(text) == .orderedSame }.map { ($0, word) }
        }
        // the Fächer column: where most subject keys line up (single letters also occur elsewhere)
        let column = densestX(subjectWords.map(\.box.midX), window: 0.05)
        let inColumn = column.map { x in subjectWords.filter { abs($0.box.midX - x) < 0.06 } } ?? []

        let cells = words.filter { word in
            guard let column, word.midX > column + 0.08 else { return false }
            let t = word.text
            return t.firstMatch(of: #/^\d\(\d/#) != nil || t.wholeMatch(of: #/\d/#) != nil || t == "-" || t == "–"
        }
        let heights = (inColumn.map(\.box) + cells).map(\.height)

        let lower = boxes.map { ($0, $0.text.lowercased()) }
        let titleSeen = lower.contains { $0.1.contains("kurswahlprotokoll") || $0.1.contains("abiturjahr") }
        let header = lower.first { t in ["fächer", "facher", "pro kurs", "fachart"].contains { t.1.contains($0) } }?.0
        let summen = lower.first { $0.1.hasPrefix("summe") }?.0
        var sumNumbers: [TextBox] = []
        if let summen {
            sumNumbers = words.filter { word in
                word.midX > summen.maxX && abs(word.midY - summen.midY) < 0.05 && word.text.wholeMatch(of: #/\d{2}\.?/#) != nil
            }
        }
        var line: [ScanPoint] = []
        if let summen {
            let end = sumNumbers.max { $0.midX < $1.midX }
            line = [ScanPoint(x: summen.x, y: summen.midY), ScanPoint(x: end?.maxX ?? summen.maxX, y: end?.midY ?? summen.midY)]
        }

        return ShotStructure(titleSeen: titleSeen, headerSeen: header != nil, summenSeen: summen != nil,
                             subjects: Set(inColumn.map(\.key)), cellValues: cells.count, sumNumbers: sumNumbers.count,
                             lineHeight: heights.median ?? 0,
                             subjectPoints: inColumn.map { ScanPoint(x: $0.box.midX, y: $0.box.midY) },
                             summenLine: line, header: header.map { ScanPoint(x: $0.midX, y: $0.midY) })
    }

    /// What is still missing for a photo step; nil when the structure is good enough.
    public func missing(for shot: KurswahlShot) -> ScanHint? {
        switch shot {
        case .overview:
            return titleSeen && summenSeen && subjects.count >= Self.minOverviewSubjects ? nil : .wholeSheet
        case .tableTop:
            let upper = subjects.intersection(Self.upperSubjects).count
            if upper >= 3 || headerSeen, lineHeight > 0, lineHeight < Self.minLineHeight { return .moveCloser }
            return headerSeen && upper >= Self.minTopSubjects && cellValues >= Self.minTopCells ? nil : .frameTableTop
        case .tableBottom:
            let lower = subjects.intersection(Self.lowerSubjects).count
            if lower >= 2 || summenSeen, lineHeight > 0, lineHeight < Self.minLineHeight { return .moveCloser }
            return summenSeen && lower >= Self.minBottomSubjects && sumNumbers >= Self.minSumNumbers ? nil : .frameTableBottom
        }
    }

    private static func densestX(_ xs: [Double], window: Double) -> Double? {
        guard let best = xs.max(by: { a, b in
            xs.filter { abs($0 - a) < window }.count < xs.filter { abs($0 - b) < window }.count
        }) else { return nil }
        return xs.filter { abs($0 - best) < window }.median
    }
}

/// Turns analysed frames into one calm instruction and decides when to take the photo.
///
/// Thresholds come from what the Kurswahlprotokoll needs to be readable: the bracketed course
/// numbers are ~2 mm tall, so the sheet has to fill ≥ 40 % of the frame; a tilt beyond ~12°
/// makes the table rows slope; a few percent of clipped white hides whole cells.
public struct ScanGuidance: Sendable {
    public static let minLuma = 0.22
    public static let minArea = 0.40
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

    /// The instruction for a frame of one photo step, with what text recognition found.
    ///
    /// The overview adds the structure check to the sheet checks. Close-ups ignore the sheet
    /// outline (it is cut on purpose, so no "move back") and rely on the structure instead.
    public static func hint(for frame: ScanFrame, shot: KurswahlShot, structure: ShotStructure?) -> ScanHint {
        let structure = structure ?? .empty
        if shot.needsSheet {
            let base = hint(for: frame)
            guard [.ready, .glare, .holdStill].contains(base) else { return base }
            return structure.missing(for: shot) ?? base
        }
        if frame.luma < minLuma { return .tooDark }
        if frame.tilt > maxTilt { return .holdParallel }
        if let quad = frame.quad, !quad.touchesEdge(margin: edgeMargin), quad.squareness < minSquareness { return .holdParallel }
        if let missing = structure.missing(for: shot) { return missing }
        if frame.glare > maxGlare { return .glare }
        // the outline of a cut sheet jumps between detections, so only the phone's motion counts
        if frame.motion > maxMotion { return .holdStill }
        return .ready
    }

    public mutating func update(_ frame: ScanFrame) -> State {
        advance(frame, raw: Self.hint(for: frame))
    }

    public mutating func update(_ frame: ScanFrame, shot: KurswahlShot, structure: ShotStructure?) -> State {
        advance(frame, raw: Self.hint(for: frame, shot: shot, structure: structure))
    }

    private mutating func advance(_ frame: ScanFrame, raw: ScanHint) -> State {
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

extension Array where Element == Double {
    fileprivate var median: Double? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
