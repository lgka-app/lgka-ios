import AVFoundation
import SwiftUI
import LGKAPlanKit

/// Guided camera for the Kurswahlprotokoll, fully automatic: outlines the sheet live, paints a
/// faint table grid on it, tells the user what to change (closer, parallel, still), turns the
/// torch on when it is too dark and takes a burst of photos by itself once everything holds.
struct KurswahlCameraScreen: View {
    /// The photos of one shot (a short burst of the same framing), upright and straightened.
    let onCapture: ([CGImage]) -> Void
    let onCancel: () -> Void

    static let burstCount = 3

    @Environment(\.appAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var camera = KurswahlCamera()
    @State private var flash = false
    /// Photos of the running burst taken so far.
    @State private var photosTaken = 0
    /// Since when the view has not been ready; after `stuckDelay` the placement tip shows.
    @State private var notReadySince = Date()
    @State private var showsPlacementTip = false

    /// How long the scan may search before the tip about a flat, non-white surface appears.
    static let stuckDelay: TimeInterval = 8

    private var hint: ScanHint { camera.state.hint }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if camera.authorization == .denied {
                permissionView
            } else {
                CameraPreview(session: camera.pipeline.session)
                    .ignoresSafeArea()
                GeometryReader { geo in sheetOverlay(size: geo.size) }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                VStack(spacing: 12) {
                    // close and the instruction share one row: X on the left, the pill centred at the same height,
                    // kept clear of the X on both sides so it stays centred on screen
                    ZStack {
                        instructionPill
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 56)
                        HStack {
                            closeButton
                            Spacer()
                        }
                    }
                    .frame(minHeight: 44)
                    .padding(.horizontal, 20)
                    if hint == .holdParallel {
                        SpiritLevel(gravity: camera.level, accent: accent)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                    if showsPlacementTip && hint != .ready && !camera.isCapturing {
                        placementTip
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.bottom, 20)
                .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.25), value: hint)
                .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.2), value: showsPlacementTip)
            }
            Color.white.opacity(flash ? (reduceMotion ? 0.35 : 0.9) : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .task {
            camera.onAutoCapture = { Task { await shoot() } }
            // at the moment the sensor takes each photo (with the shutter sound), not when it is processed
            camera.onPhotoTaken = { photoTaken($0) }
            await camera.start()
        }
        .task {
            // searching for too long: most often the sheet is held in the hand or lies on a white table
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                let stuck = hint != .ready && !camera.isCapturing && Date().timeIntervalSince(notReadySince) >= Self.stuckDelay
                if stuck && !showsPlacementTip {
                    showsPlacementTip = true
                    AccessibilityNotification.Announcement(L.s("scan.stuck")).post()
                }
            }
        }
        .onDisappear { camera.stop() }
        .onChange(of: hint) { old, new in
            if new == .ready {
                showsPlacementTip = false
            } else if old == .ready {
                notReadySince = Date()
            }
            guard !camera.isCapturing else { return }
            if new == .ready { Haptics.light() }
            AccessibilityNotification.Announcement(Self.text(for: new)).post()
        }
    }

    // MARK: Overlay

    private func sheetOverlay(size: CGSize) -> some View {
        let detected = camera.quad.map { mapped($0, into: size) }
        let corners = detected ?? guideCorners(in: size)
        let vector = QuadVector(corners)
        let ready = hint == .ready
        let tint = ready ? accent : .white
        return ZStack {
            SheetDim(quad: vector)
                .fill(.black.opacity(detected == nil ? 0.35 : 0.5), style: FillStyle(eoFill: true))
            SheetGrid(quad: vector)
                .stroke(.white.opacity(detected == nil ? 0.1 : 0.22), lineWidth: 0.75)
            SheetOutline(quad: vector)
                .stroke(tint.opacity(detected == nil ? 0.5 : 0.9),
                        style: StrokeStyle(lineWidth: detected == nil ? 1.5 : 2, dash: detected == nil ? [6, 6] : []))
            CornerBrackets(quad: vector, length: 26)
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .shadow(color: tint.opacity(ready ? 0.8 : 0.3), radius: ready ? 10 : 4)
        }
        .animation(reduceMotion ? nil : .interpolatingSpring(stiffness: 170, damping: 22), value: vector)
        .animation(.easeInOut(duration: 0.25), value: ready)
    }

    /// Frame coordinates (portrait, 0…1) → view points, as the preview fills the view.
    private func mapped(_ quad: ScanQuad, into size: CGSize) -> [CGPoint] {
        let aspect = max(camera.frameAspect, 0.1)
        let content: CGSize = size.width / size.height > aspect
            ? CGSize(width: size.width, height: size.width / aspect)
            : CGSize(width: size.height * aspect, height: size.height)
        let dx = (size.width - content.width) / 2, dy = (size.height - content.height) / 2
        return quad.corners.map { CGPoint(x: dx + $0.x * content.width, y: dy + $0.y * content.height) }
    }

    /// A centred A4-portrait frame showing where the sheet should go.
    private func guideCorners(in size: CGSize) -> [CGPoint] {
        let width = min(size.width * 0.8, size.height * 0.6 / 1.414)
        let height = width * 1.414
        let rect = CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2 - 10, width: width, height: height)
        return [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    // MARK: Instruction

    /// Shown after `stuckDelay` without a ready frame; gone as soon as the frame is ready.
    private var placementTip: some View {
        Label {
            Text(L.s("scan.stuck"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
                .fixedSize()
        } icon: {
            Image(systemName: "hand.raised.slash.fill")
                .foregroundStyle(accent)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 420, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private var instructionPill: some View {
        let bursting = camera.isCapturing
        let highlighted = hint == .ready || bursting
        return HStack(spacing: 10) {
            Image(systemName: bursting ? "hand.raised.fill" : Self.symbol(for: hint))
                .font(.body.weight(.semibold))
                .foregroundStyle(highlighted ? accent : .white)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, isActive: (hint == .tooDark || hint == .noDocument) && !bursting && !reduceMotion)
            Text(bursting ? L.s("scan.burst.hold") : Self.text(for: hint))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .contentTransition(.opacity)
            if bursting {
                BurstDots(taken: photosTaken, total: Self.burstCount, accent: accent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular.tint(highlighted ? accent.opacity(0.3) : nil), in: .capsule)
        .animation(reduceMotion ? nil : .spring(duration: 0.3), value: bursting)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    static func symbol(for hint: ScanHint) -> String {
        switch hint {
        case .noDocument: "doc.viewfinder"
        case .tooDark: "lightbulb.fill"
        case .moveCloser: "plus.magnifyingglass"
        case .moveBack: "minus.magnifyingglass"
        case .holdParallel: "level"
        case .glare: "sun.max.fill"
        case .holdStill: "hand.raised.fill"
        case .ready: "checkmark.circle.fill"
        }
    }

    static func text(for hint: ScanHint) -> String {
        L.s("scan.hint.\(hint.rawValue)")
    }

    // MARK: Controls

    private var closeButton: some View {
        Button {
            Haptics.light()
            onCancel()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(L.s("scan.close"))
    }

    private func shoot() async {
        guard !camera.isCapturing, camera.authorization == .allowed else { return }
        photosTaken = 0
        let images = await camera.capture(count: Self.burstCount)
        if !images.isEmpty {
            camera.stop()
            onCapture(images)
        } else {
            photosTaken = 0
            Haptics.error()
        }
    }

    /// The shutter effect for every single photo of the burst.
    private func photoTaken(_ index: Int) {
        photosTaken = index + 1
        Haptics.success()
        AccessibilityNotification.Announcement(L.f("scan.burst.photo", index + 1, Self.burstCount)).post()
        withAnimation(.easeOut(duration: 0.06)) { flash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.easeOut(duration: 0.3)) { flash = false }
        }
    }

    // MARK: Permission

    private var permissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(L.s("scan.permission.title"))
                .font(.title3.bold())
            Text(L.s("scan.permission.body"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L.s("scan.permission.settings")) {
                Haptics.light()
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.glassProminent)
            .tint(accent)
            .padding(.top, 8)
            Button(L.s("scan.close")) {
                Haptics.light()
                onCancel()
            }
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .padding(32)
    }
}

// MARK: - Camera preview

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        // swiftlint:disable:next force_cast
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }
}

// MARK: - Burst dots

/// One dot per photo of the burst, filled as each is taken.
private struct BurstDots: View {
    let taken: Int
    let total: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < taken ? accent : .white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == taken - 1 ? 1.25 : 1)
                    .animation(.spring(duration: 0.25, bounce: 0.5), value: taken)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Spirit level

private struct SpiritLevel: View {
    let gravity: CGPoint
    let accent: Color

    var body: some View {
        let radius: CGFloat = 26
        // gravity of ~0.34 (20°) reaches the rim; the bubble drifts to the higher side
        let dx = max(-1, min(1, -gravity.x / 0.34)) * radius
        let dy = max(-1, min(1, gravity.y / 0.34)) * radius
        let centred = hypot(dx, dy) < 6
        ZStack {
            Circle().stroke(.white.opacity(0.5), lineWidth: 1.5)
            Circle().stroke(.white.opacity(0.35), lineWidth: 1).padding(radius - 8)
            Circle()
                .fill(centred ? accent : .white)
                .frame(width: 16, height: 16)
                .offset(x: dx, y: dy)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.7), value: gravity)
        }
        .frame(width: radius * 2 + 16, height: radius * 2 + 16)
        .padding(10)
        .glassEffect(in: .circle)
        .accessibilityHidden(true)
    }
}

// MARK: - Animatable sheet shapes

/// Four corners as one animatable vector, so the outline glides between detections.
struct QuadVector: VectorArithmetic, Hashable {
    var values: SIMD8<Double>

    init(values: SIMD8<Double>) { self.values = values }

    init(_ points: [CGPoint]) {
        var v = SIMD8<Double>()
        for (i, p) in points.prefix(4).enumerated() {
            v[i * 2] = p.x
            v[i * 2 + 1] = p.y
        }
        values = v
    }

    var points: [CGPoint] { (0..<4).map { CGPoint(x: values[$0 * 2], y: values[$0 * 2 + 1]) } }

    static var zero: QuadVector { QuadVector(values: .zero) }
    static func + (lhs: QuadVector, rhs: QuadVector) -> QuadVector { QuadVector(values: lhs.values + rhs.values) }
    static func - (lhs: QuadVector, rhs: QuadVector) -> QuadVector { QuadVector(values: lhs.values - rhs.values) }
    mutating func scale(by rhs: Double) { values *= rhs }
    var magnitudeSquared: Double { (values * values).sum() }

    /// Bilinear point inside the quad: u across, v down.
    func point(u: Double, v: Double) -> CGPoint {
        let p = points
        let top = CGPoint(x: p[0].x + (p[1].x - p[0].x) * u, y: p[0].y + (p[1].y - p[0].y) * u)
        let bottom = CGPoint(x: p[3].x + (p[2].x - p[3].x) * u, y: p[3].y + (p[2].y - p[3].y) * u)
        return CGPoint(x: top.x + (bottom.x - top.x) * v, y: top.y + (bottom.y - top.y) * v)
    }
}

private struct SheetDim: Shape {
    var quad: QuadVector
    var animatableData: QuadVector {
        get { quad }
        set { quad = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addLines(quad.points)
        path.closeSubpath()
        return path
    }
}

private struct SheetOutline: Shape {
    var quad: QuadVector
    var animatableData: QuadVector {
        get { quad }
        set { quad = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(quad.points)
        path.closeSubpath()
        return path
    }
}

/// The Kurswahlprotokoll's table as a faint grid: subject rows and the Fachart / hours columns.
private struct SheetGrid: Shape {
    var quad: QuadVector
    var animatableData: QuadVector {
        get { quad }
        set { quad = newValue }
    }

    private static let rows: [Double] = stride(from: 0.30, through: 0.88, by: 0.0322).map { $0 }
    private static let columns: [Double] = [0.07, 0.25, 0.33, 0.40, 0.46, 0.52, 0.58, 0.64, 0.70, 0.78, 0.93]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = Self.rows.first ?? 0.3, bottom = Self.rows.last ?? 0.88
        for v in Self.rows {
            path.move(to: quad.point(u: Self.columns.first ?? 0, v: v))
            path.addLine(to: quad.point(u: Self.columns.last ?? 1, v: v))
        }
        for u in Self.columns {
            path.move(to: quad.point(u: u, v: top))
            path.addLine(to: quad.point(u: u, v: bottom))
        }
        return path
    }
}

private struct CornerBrackets: Shape {
    var quad: QuadVector
    var length: CGFloat
    var animatableData: QuadVector {
        get { quad }
        set { quad = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let p = quad.points
        for i in 0..<4 {
            let corner = p[i], next = p[(i + 1) % 4], previous = p[(i + 3) % 4]
            path.move(to: toward(corner, next))
            path.addLine(to: corner)
            path.addLine(to: toward(corner, previous))
        }
        return path
    }

    private func toward(_ from: CGPoint, _ to: CGPoint) -> CGPoint {
        let dx = to.x - from.x, dy = to.y - from.y
        let distance = max(hypot(dx, dy), 1)
        let l = min(length, distance / 3)
        return CGPoint(x: from.x + dx / distance * l, y: from.y + dy / distance * l)
    }
}
