import ARKit
import AVFoundation
import Vision
import simd
import UIKit
import LGKACore

// MARK: - Geometry

/// The paper fixed in the world: origin at its top-left corner, x along the top edge, y down the left edge.
struct SheetFrame: Sendable, Equatable {
    var origin: SIMD3<Float>
    var xAxis: SIMD3<Float>
    var yAxis: SIMD3<Float>
    var normal: SIMD3<Float>
    /// Metres.
    var width: Float
    var height: Float

    /// World point of a sheet point (0…1, origin top-left).
    func world(_ u: Double, _ v: Double) -> SIMD3<Float> {
        origin + xAxis * (width * Float(u)) + yAxis * (height * Float(v))
    }

    func sheet(_ point: SIMD3<Float>) -> (u: Double, v: Double) {
        let d = point - origin
        return (Double(simd_dot(d, xAxis) / width), Double(simd_dot(d, yAxis) / height))
    }

    func intersect(from start: SIMD3<Float>, direction: SIMD3<Float>) -> SIMD3<Float>? {
        Plane(point: origin, normal: normal).intersect(from: start, direction: direction)
    }
}

struct Plane: Sendable {
    var point: SIMD3<Float>
    var normal: SIMD3<Float>

    func intersect(from start: SIMD3<Float>, direction: SIMD3<Float>) -> SIMD3<Float>? {
        let denominator = simd_dot(normal, direction)
        guard abs(denominator) > 1e-5 else { return nil }
        let t = simd_dot(point - start, normal) / denominator
        return t > 0.02 && t < 3 ? start + direction * t : nil
    }
}

/// What the renderer and the reader need of one ARFrame (ARFrames themselves must not be kept).
struct CameraSnapshot: Sendable {
    var transform: simd_float4x4
    var intrinsics: simd_float3x3
    /// Sensor image size in pixels (landscape).
    var imageSize: CGSize
    var viewMatrix: simd_float4x4
    var projectionMatrix: simd_float4x4
    var viewport: CGSize
    var displayTransform: CGAffineTransform

    var position: SIMD3<Float> { SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z) }

    /// World ray through a point of the upright portrait image (0…1, origin top-left).
    /// The portrait image is the sensor image turned 90° clockwise.
    func ray(_ u: Double, _ v: Double) -> SIMD3<Float> {
        let sx = Float(v) * Float(imageSize.width), sy = Float(1 - u) * Float(imageSize.height)
        let fx = intrinsics[0][0], fy = intrinsics[1][1], cx = intrinsics[2][0], cy = intrinsics[2][1]
        let direction = transform * SIMD4<Float>((sx - cx) / fx, -(sy - cy) / fy, -1, 0)
        return simd_normalize(SIMD3(direction.x, direction.y, direction.z))
    }

    /// Portrait image point (0…1) and pixel scale of a world point; nil behind the camera.
    func imagePoint(_ world: SIMD3<Float>) -> (u: Double, v: Double)? {
        let local = transform.inverse * SIMD4(world, 1)
        guard local.z < -0.01 else { return nil }
        let fx = intrinsics[0][0], fy = intrinsics[1][1], cx = intrinsics[2][0], cy = intrinsics[2][1]
        let sx = fx * local.x / -local.z + cx
        let sy = -fy * local.y / -local.z + cy
        return (1 - Double(sy) / imageSize.height, Double(sx) / imageSize.width)
    }

    /// Screen point of a world point; nil behind the camera.
    func project(_ world: SIMD3<Float>) -> CGPoint? {
        let clip = projectionMatrix * viewMatrix * SIMD4(world, 1)
        guard clip.w > 0.001 else { return nil }
        let x = clip.x / clip.w, y = clip.y / clip.w
        return CGPoint(x: CGFloat((x + 1) / 2) * viewport.width, y: CGFloat((1 - y) / 2) * viewport.height)
    }

    /// Screen point of a portrait image point (0…1, origin top-left).
    func viewPoint(_ u: Double, _ v: Double) -> CGPoint {
        let normalized = CGPoint(x: v, y: 1 - u).applying(displayTransform)
        return CGPoint(x: normalized.x * viewport.width, y: normalized.y * viewport.height)
    }
}

// MARK: - Tracker

/// Runs on the AR session's delegate queue: finds the paper, fixes it in the world, then reads text
/// ~3 times a second and maps every recognised box onto the sheet for `SheetScanAccumulator`.
final class SheetTracker: NSObject, ARSessionDelegate, @unchecked Sendable {
    enum TrackingHint: Sendable, Equatable { case moreLight, slower }

    struct Update: Sendable {
        var camera: CameraSnapshot
        /// The detected paper in screen points (TL, TR, BR, BL), until the sheet is fixed.
        var quad: [CGPoint]?
        var sheet: SheetFrame?
        var hint: TrackingHint?
    }

    struct Reading: Sendable {
        var progress: ScanProgress
        /// Per cell (row by row), 0…1: how well that part of the sheet has been seen.
        var coverage: [Float]
        var boxes: [TextBox]
        var aspect: Double
    }

    static let columns = 20
    static let rows = 28

    var onUpdate: (@Sendable (Update) -> Void)?
    var onReading: (@Sendable (Reading) -> Void)?

    let frameQueue = DispatchQueue(label: "com.lgka.scan.frames")
    private let detectQueue = DispatchQueue(label: "com.lgka.scan.detect")
    private let readQueue = DispatchQueue(label: "com.lgka.scan.read")
    private let lock = NSLock()

    private let schuljahr: String?
    private let halbjahr: String

    // shared (lock)
    private var viewport = CGSize.zero
    private var fixedSheet: SheetFrame?
    private var quad: [CGPoint]?
    private var detecting = false
    private var reading = false
    private var detections: [[SIMD3<Float>]] = []

    // frame queue only
    private var lastPublish: TimeInterval = 0
    private var lastDetect: TimeInterval = 0
    private var lastRead: TimeInterval = 0

    // read queue only
    private var accumulator = SheetScanAccumulator()
    private var coverage = [Float](repeating: 0, count: SheetTracker.columns * SheetTracker.rows)

    init(schuljahr: String?, halbjahr: String) {
        self.schuljahr = schuljahr
        self.halbjahr = halbjahr
    }

    func setViewport(_ size: CGSize) {
        lock.withLock { viewport = size }
    }

    static func configuration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isAutoFocusEnabled = true
        // the sharpest 4:3 format: small printed digits need pixels
        let formats = ARWorldTrackingConfiguration.supportedVideoFormats.filter { format in
            abs(format.imageResolution.width / format.imageResolution.height - 4.0 / 3.0) < 0.02
        }
        if let best = formats.max(by: { $0.imageResolution.width * $0.imageResolution.height < $1.imageResolution.width * $1.imageResolution.height }) {
            configuration.videoFormat = best
        }
        return configuration
    }

    // MARK: ARSessionDelegate (frame queue)

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let viewportSize = lock.withLock { viewport }
        guard viewportSize.width > 0 else { return }
        let now = frame.timestamp
        let camera = CameraSnapshot(
            transform: frame.camera.transform, intrinsics: frame.camera.intrinsics, imageSize: frame.camera.imageResolution,
            viewMatrix: frame.camera.viewMatrix(for: .portrait),
            projectionMatrix: frame.camera.projectionMatrix(for: .portrait, viewportSize: viewportSize, zNear: 0.001, zFar: 100),
            viewport: viewportSize, displayTransform: frame.displayTransform(for: .portrait, viewportSize: viewportSize))
        let light = Double(frame.lightEstimate?.ambientIntensity ?? 1000)
        let hint: TrackingHint? = switch frame.camera.trackingState {
        case .limited(.excessiveMotion): .slower
        case .limited(.insufficientFeatures): light < 350 ? .moreLight : .slower
        case .normal: light < 180 ? .moreLight : nil
        default: nil
        }

        let (sheet, busyDetecting, busyReading) = lock.withLock { (fixedSheet, detecting, reading) }
        if sheet == nil, !busyDetecting, now - lastDetect > 0.12 {
            lastDetect = now
            let planes = frame.anchors.compactMap { $0 as? ARPlaneAnchor }.map { anchor in
                Plane(point: SIMD3(anchor.transform.columns.3.x, anchor.transform.columns.3.y, anchor.transform.columns.3.z),
                      normal: simd_normalize(SIMD3(anchor.transform.columns.1.x, anchor.transform.columns.1.y, anchor.transform.columns.1.z)))
            }
            let buffer = PixelBuffer(frame.capturedImage)
            lock.withLock { detecting = true }
            detectQueue.async { [self] in detectSheet(buffer, camera: camera, planes: planes) }
        }
        if let sheet, !busyReading, now - lastRead > 0.33 {
            lastRead = now
            let buffer = PixelBuffer(frame.capturedImage)
            lock.withLock { reading = true }
            readQueue.async { [self] in read(buffer, camera: camera, sheet: sheet) }
        }
        if now - lastPublish > 1.0 / 30 {
            lastPublish = now
            let currentQuad = lock.withLock { quad }
            onUpdate?(Update(camera: camera, quad: sheet == nil ? currentQuad : nil, sheet: sheet, hint: hint))
        }
    }

    // MARK: Finding the paper (detect queue)

    private func detectSheet(_ buffer: PixelBuffer, camera: CameraSnapshot, planes: [Plane]) {
        defer { lock.withLock { detecting = false } }
        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer.buffer, orientation: .right)
        guard (try? handler.perform([request])) != nil, let document = request.results?.first, document.confidence > 0.6 else {
            lock.withLock { quad = nil }
            return
        }
        // Vision: portrait image, 0…1, origin bottom-left
        let corners = [document.topLeft, document.topRight, document.bottomRight, document.bottomLeft]
            .map { (u: Double($0.x), v: Double(1 - $0.y)) }
        lock.withLock { quad = corners.map { camera.viewPoint($0.u, $0.v) } }

        // the plane the paper lies on: the nearest detected plane the centre ray hits
        let start = camera.position
        let centre = camera.ray(corners.map(\.u).reduce(0, +) / 4, corners.map(\.v).reduce(0, +) / 4)
        guard let plane = planes
            .compactMap({ plane in plane.intersect(from: start, direction: centre).map { (plane, simd_distance($0, start)) } })
            .min(by: { $0.1 < $1.1 })?.0 else { return }
        let world = corners.compactMap { plane.intersect(from: start, direction: camera.ray($0.u, $0.v)) }
        guard world.count == 4 else { return }
        let width = (simd_distance(world[0], world[1]) + simd_distance(world[3], world[2])) / 2
        let height = (simd_distance(world[0], world[3]) + simd_distance(world[1], world[2])) / 2
        // about an A4 sheet in portrait (210 × 297 mm)
        guard width > 0.12, width < 0.4, (1.2...1.65).contains(height / width) else { return }

        lock.withLock {
            detections.append(world)
            if detections.count > 6 { detections.removeFirst() }
            guard detections.count >= 5 else { return }
            let recent = detections.suffix(5)
            let mean = (0..<4).map { i in recent.map { $0[i] }.reduce(SIMD3<Float>.zero, +) / Float(recent.count) }
            let steady = recent.allSatisfy { detection in (0..<4).allSatisfy { simd_distance(detection[$0], mean[$0]) < 0.02 } }
            guard steady else { return }
            fixedSheet = Self.sheet(corners: mean)
            quad = nil
        }
    }

    private static func sheet(corners c: [SIMD3<Float>]) -> SheetFrame {
        let x = simd_normalize((c[1] - c[0]) + (c[2] - c[3]))
        let down = (c[3] - c[0]) + (c[2] - c[1])
        let normal = simd_normalize(simd_cross(x, down))
        var y = simd_normalize(simd_cross(normal, x))
        if simd_dot(y, down) < 0 { y = -y }
        return SheetFrame(origin: c[0], xAxis: x, yAxis: y, normal: normal,
                          width: (simd_distance(c[0], c[1]) + simd_distance(c[3], c[2])) / 2,
                          height: (simd_distance(c[0], c[3]) + simd_distance(c[1], c[2])) / 2)
    }

    // MARK: Reading (read queue)

    private func read(_ buffer: PixelBuffer, camera: CameraSnapshot, sheet: SheetFrame) {
        defer { lock.withLock { reading = false } }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["de-DE"]
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer.buffer, orientation: .right)
        guard (try? handler.perform([request])) != nil else { return }

        let start = camera.position
        var boxes: [TextBox] = []
        var heights: [Double] = []
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let b = observation.boundingBox // portrait image, 0…1, origin bottom-left
            let top = 1 - Double(b.maxY), bottom = 1 - Double(b.minY)
            let corners = [(Double(b.minX), top), (Double(b.maxX), top), (Double(b.maxX), bottom), (Double(b.minX), bottom)]
            let onSheet = corners.compactMap { corner in
                sheet.intersect(from: start, direction: camera.ray(corner.0, corner.1)).map { sheet.sheet($0) }
            }
            guard onSheet.count == 4 else { continue }
            let us = onSheet.map(\.u), vs = onSheet.map(\.v)
            guard let u0 = us.min(), let u1 = us.max(), let v0 = vs.min(), let v1 = vs.max() else { continue }
            let box = TextBox(text: candidate.string, x: u0, y: v0, width: u1 - u0, height: v1 - v0,
                              confidence: Double(candidate.confidence))
            guard (-0.02...1.02).contains(box.midX), (-0.02...1.02).contains(box.midY) else { continue }
            boxes.append(box)
            heights.append(Double(b.height) * camera.imageSize.width) // portrait height = sensor width
        }
        // larger text in the frame reads more reliably
        let medianHeight = heights.sorted().dropFirst(heights.count / 2).first ?? 0
        let quality = min(1.5, max(0.2, medianHeight / 28))
        if !boxes.isEmpty { accumulator.add(boxes, quality: quality) }
        markCoverage(camera: camera, sheet: sheet)

        let progress = accumulator.progress(schuljahr: schuljahr, halbjahr: halbjahr)
        onReading?(Reading(progress: progress, coverage: coverage, boxes: accumulator.boxes, aspect: accumulator.aspect))
    }

    /// Cells of the sheet inside this frame, scored by how large they appear (a cell ≥ 44 px tall reads well).
    private func markCoverage(camera: CameraSnapshot, sheet: SheetFrame) {
        let columns = Self.columns, rows = Self.rows
        for row in 0..<rows {
            for column in 0..<columns {
                let u = (Double(column) + 0.5) / Double(columns), v = (Double(row) + 0.5) / Double(rows)
                guard let centre = camera.imagePoint(sheet.world(u, v)),
                      (0.03...0.97).contains(centre.u), (0.03...0.97).contains(centre.v),
                      let above = camera.imagePoint(sheet.world(u, v - 0.5 / Double(rows))),
                      let below = camera.imagePoint(sheet.world(u, v + 0.5 / Double(rows))) else { continue }
                let pixels = hypot((below.u - above.u) * camera.imageSize.height, (below.v - above.v) * camera.imageSize.width)
                let score = Float(min(1, pixels / 44))
                let index = row * columns + column
                if score > coverage[index] { coverage[index] = score }
            }
        }
    }
}

/// A camera pixel buffer handed to another queue; only one at a time per queue is alive.
struct PixelBuffer: @unchecked Sendable {
    let buffer: CVPixelBuffer
    init(_ buffer: CVPixelBuffer) { self.buffer = buffer }
}
