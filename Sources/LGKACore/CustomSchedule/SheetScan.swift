import Foundation

/// Text read while the phone moves over a Kurswahlprotokoll, gathered from many camera frames.
/// Boxes arrive in sheet coordinates (0…1 of the paper, origin top-left), so the same printed value
/// seen in different frames lands in the same place; every place keeps the reading with the most
/// weight (recognition confidence × how large the text was in that frame), so a misread in one
/// frame is outvoted by the frames that read it right.
public struct SheetScanAccumulator: Sendable {
    /// Sheet height ÷ width (A4 portrait).
    public let aspect: Double
    public private(set) var frames = 0
    private var words: [Cluster] = []
    private var lines: [Cluster] = []

    struct Cluster: Sendable {
        var x: Double
        var y: Double
        var observations: Int
        var readings: [String: Reading]
    }

    struct Reading: Sendable {
        var score: Double
        var count: Int
        var best: TextBox
        var bestWeight: Double
    }

    public init(aspect: Double = 297.0 / 210.0) {
        self.aspect = aspect
    }

    /// One frame's recognised text. `quality` scales its weight: larger text in the frame reads better.
    public mutating func add(_ boxes: [TextBox], quality: Double = 1) {
        frames += 1
        for box in boxes {
            let text = box.text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            // whole lines keep labels like "pro Kurs" and names together; single words carry the values
            if text.contains(" ") { Self.insert(box, into: &lines, tolerance: (0.03, 0.006), quality: quality) }
            for word in box.words() { Self.insert(word, into: &words, tolerance: (0.012, 0.005), quality: quality) }
        }
    }

    /// The winning reading of every place, confidence = its share of the weight there.
    public var boxes: [TextBox] {
        (words + lines).compactMap { cluster in
            guard let (text, reading) = cluster.readings.max(by: { $0.value.score < $1.value.score }) else { return nil }
            let total = cluster.readings.values.reduce(0) { $0 + $1.score }
            var box = reading.best
            box.text = text
            box.confidence = min(1, reading.score / max(total, 0.000_1)) * min(1, 0.5 + Double(reading.count) * 0.25)
            return box
        }
    }

    public func progress(schuljahr: String?, halbjahr: String) -> ScanProgress {
        guard frames > 0, let detail = try? KurswahlParser.parseDetailed(boxes, aspect: aspect) else {
            return ScanProgress(kurswahl: nil, hours: 0, sum: nil, subjects: 0, rows: 0, complete: false, marks: [])
        }
        let kurswahl = detail.kurswahl
        let grade = schuljahr.flatMap { kurswahl.grade(inSchuljahr: $0) } ?? 11
        let half = min(Kurswahl.halfIndex(grade: grade, halbjahr: halbjahr), max(0, detail.readCells.count - 1))
        let sum = half < kurswahl.sums.count ? kurswahl.sums[half] : nil

        // hours actually read (not filled in); the small "-" of subjects not taken is often never
        // recognised, so completeness is the sheet's own sum being matched, not every cell read
        let hours = kurswahl.rows.compactMap { row in
            half < row.halves.count && row.halves[half].inferred != true ? row.halves[half].hours : nil
        }
        .reduce(0, +)
        let subjects = kurswahl.rows.filter { $0.subject != "?" }.count
        let complete = sum != nil && sum == hours && subjects >= 8

        var marks = detail.subjectBoxes.map { ScanProgress.Mark(x: $0.midX, y: $0.midY, text: $0.text, kind: .subject) }
        if half < detail.cellBoxes.count {
            marks += detail.cellBoxes[half].map { .init(x: $0.midX, y: $0.midY, text: $0.text, kind: .value) }
        }
        if half < detail.sumBoxes.count {
            let box = detail.sumBoxes[half]
            marks.append(.init(x: box.midX, y: box.midY, text: box.text, kind: .sum))
        }
        return ScanProgress(kurswahl: kurswahl, hours: hours, sum: sum, subjects: detail.subjectBoxes.count,
                            rows: detail.tableRows, complete: complete, marks: marks)
    }

    private static func insert(_ box: TextBox, into clusters: inout [Cluster], tolerance: (x: Double, y: Double), quality: Double) {
        let weight = max(0.05, box.confidence ?? 0.5) * quality
        let index = clusters.firstIndex { abs($0.x - box.midX) < tolerance.x && abs($0.y - box.midY) < tolerance.y }
        guard let index else {
            clusters.append(Cluster(x: box.midX, y: box.midY, observations: 1,
                                    readings: [box.text: Reading(score: weight, count: 1, best: box, bestWeight: weight)]))
            return
        }
        var cluster = clusters[index]
        var reading = cluster.readings[box.text] ?? Reading(score: 0, count: 0, best: box, bestWeight: 0)
        reading.score += weight
        reading.count += 1
        if weight > reading.bestWeight {
            reading.best = box
            reading.bestWeight = weight
        }
        cluster.readings[box.text] = reading
        cluster.observations += 1
        cluster.x += (box.midX - cluster.x) / Double(cluster.observations)
        cluster.y += (box.midY - cluster.y) / Double(cluster.observations)
        clusters[index] = cluster
    }
}

/// How far a live scan is: the counter, whether the plan's values are all read, and where the
/// read values sit on the sheet (to light them up in the camera view).
public struct ScanProgress: Sendable, Equatable {
    public var kurswahl: Kurswahl?
    /// Weekly hours read so far for the plan's Halbjahr, the counter that goes up while scanning.
    public var hours: Int
    /// The sheet's own sum for that Halbjahr, once read: the counter's goal.
    public var sum: Int?
    /// Subject abbreviations recognised in the Fächer column.
    public var subjects: Int
    /// Table rows between header and sums (estimated); 0 until the table is recognised.
    public var rows: Int
    /// The sum is read and the hours read add up to it.
    public var complete: Bool
    public var marks: [Mark]

    public struct Mark: Sendable, Equatable {
        public enum Kind: Sendable, Equatable { case subject, value, sum }
        /// Sheet coordinates, 0…1, origin top-left.
        public var x: Double
        public var y: Double
        public var text: String
        public var kind: Kind
    }
}
