import AVFoundation
import SwiftUI
import LGKAPlanKit

/// Guided camera for the Kurswahlprotokoll in three forced photos: the whole sheet, then the upper
/// and the lower half of the table up close. Live trackers mark what text recognition sees (the
/// subject column, the table header, the "Summen" row), the instruction says what to change, and
/// each photo is taken by itself once its part of the sheet is framed and readable.
struct KurswahlCameraScreen: View {
    let onFinish: ([CGImage]) -> Void   // one upright image per KurswahlShot, in allCases order
    let onCancel: () -> Void

    @Environment(\.appAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var camera = KurswahlCamera()
    @State private var images: [KurswahlShot: CGImage] = [:]
    @State private var thumbnails: [KurswahlShot: UIImage] = [:]
    @State private var flash = false
    @State private var shutterDown = false

    private var hint: ScanHint { camera.state.hint }
    private var shot: KurswahlShot { camera.shot }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if camera.authorization == .denied {
                permissionView
            } else {
                CameraPreview(session: camera.pipeline.session)
                    .ignoresSafeArea()
                GeometryReader { geo in
                    ZStack {
                        if shot.needsSheet { sheetOverlay(size: geo.size) } else { closeUpOverlay(size: geo.size) }
                        trackerMarkers(size: geo.size)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                VStack(spacing: 10) {
                    stepHeader
                    instructionPill
                    if hint == .holdParallel {
                        SpiritLevel(gravity: camera.level, accent: accent)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                    Spacer()
                    shotStrip
                    controls
                }
                .padding(.top, 12)
                .padding(.bottom, 20)
                .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.25), value: hint)
                .animation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.2), value: shot)
            }
            Color.white.opacity(flash ? 0.9 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .task {
            camera.onAutoCapture = { Task { await shoot() } }
            await camera.start()
            announceStep()
        }
        .onDisappear { camera.stop() }
        .onChange(of: hint) { _, new in
            if new == .ready { Haptics.light() }
            AccessibilityNotification.Announcement(Self.text(for: new)).post()
        }
    }

    // MARK: Step header

    private var stepHeader: some View {
        HStack(spacing: 12) {
            StepDiagram(shot: shot, accent: accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(L.f("scan.step.progress", shot.rawValue + 1, KurswahlShot.allCases.count))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
                Text(Self.title(for: shot))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)
            }
            HStack(spacing: 6) {
                ForEach(KurswahlShot.allCases, id: \.self) { step in
                    Capsule()
                        .fill(step == shot ? accent : .white.opacity(images[step] == nil ? 0.3 : 0.75))
                        .frame(width: step == shot ? 18 : 7, height: 7)
                }
            }
            .padding(.leading, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stepAnnouncement)
    }

    private var stepAnnouncement: String {
        L.f("scan.a11y.step", shot.rawValue + 1, KurswahlShot.allCases.count, Self.title(for: shot))
    }

    private func announceStep() {
        AccessibilityNotification.Announcement(stepAnnouncement).post()
    }

    static func title(for shot: KurswahlShot) -> String {
        switch shot {
        case .overview: L.s("scan.step.overview")
        case .tableTop: L.s("scan.step.tableTop")
        case .tableBottom: L.s("scan.step.tableBottom")
        }
    }

    // MARK: Overlay

    private func sheetOverlay(size: CGSize) -> some View {
        let detected = camera.quad.map { quad in quad.corners.map { mapped($0, into: size) } }
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

    /// Close-ups fill the frame with half the table: a wide frame guide with brackets and faint rows.
    private func closeUpOverlay(size: CGSize) -> some View {
        let rect = CGRect(x: size.width * 0.05, y: size.height * 0.2, width: size.width * 0.9, height: size.height * 0.6)
        let vector = QuadVector([CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                                 CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)])
        let ready = hint == .ready
        let tint = ready ? accent : .white
        return ZStack {
            SheetDim(quad: vector)
                .fill(.black.opacity(0.28), style: FillStyle(eoFill: true))
            CloseUpRows(quad: vector)
                .stroke(.white.opacity(0.12), lineWidth: 0.75)
            CornerBrackets(quad: vector, length: 30)
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .shadow(color: tint.opacity(ready ? 0.8 : 0.3), radius: ready ? 10 : 4)
        }
        .animation(.easeInOut(duration: 0.25), value: ready)
    }

    /// What text recognition sees: dots on the subject column, the "Summen" row, the table header.
    private func trackerMarkers(size: CGSize) -> some View {
        let structure = camera.structure
        let points = structure.subjectPoints.map { mapped($0, into: size) }
        let line = structure.summenLine.map { mapped($0, into: size) }
        return ZStack {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(accent)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .frame(width: 9, height: 9)
                    .shadow(color: accent.opacity(0.7), radius: 5)
                    .position(point)
            }
            if line.count == 2 {
                Path { path in
                    path.move(to: line[0])
                    path.addLine(to: line[1])
                }
                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .shadow(color: accent.opacity(0.8), radius: 6)
            }
            if let header = structure.header {
                Image(systemName: "tablecells")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(accent, in: .circle)
                    .shadow(color: accent.opacity(0.7), radius: 6)
                    .position(mapped(header, into: size))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: structure)
    }

    /// Frame coordinates (portrait, 0…1) → view points, as the preview fills the view.
    private func mapped(_ point: ScanPoint, into size: CGSize) -> CGPoint {
        let aspect = max(camera.frameAspect, 0.1)
        let content: CGSize = size.width / size.height > aspect
            ? CGSize(width: size.width, height: size.width / aspect)
            : CGSize(width: size.height * aspect, height: size.height)
        let dx = (size.width - content.width) / 2, dy = (size.height - content.height) / 2
        return CGPoint(x: dx + point.x * content.width, y: dy + point.y * content.height)
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

    private var instructionPill: some View {
        HStack(spacing: 10) {
            Image(systemName: Self.symbol(for: hint))
                .font(.body.weight(.semibold))
                .foregroundStyle(hint == .ready ? accent : .white)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, isActive: [.tooDark, .noDocument, .wholeSheet].contains(hint) && !reduceMotion)
            Text(Self.text(for: hint))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular.tint(hint == .ready ? accent.opacity(0.3) : nil), in: .capsule)
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
        case .wholeSheet: "doc.text.viewfinder"
        case .frameTableTop: "rectangle.tophalf.inset.filled"
        case .frameTableBottom: "rectangle.bottomhalf.inset.filled"
        }
    }

    static func text(for hint: ScanHint) -> String {
        L.s("scan.hint.\(hint.rawValue)")
    }

    // MARK: Shots

    private var shotStrip: some View {
        HStack(spacing: 10) {
            ForEach(KurswahlShot.allCases, id: \.self) { step in
                let taken = thumbnails[step]
                Button {
                    retake(step)
                } label: {
                    ZStack {
                        if let taken {
                            Image(uiImage: taken)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Text("\(step.rawValue + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(step == shot ? 0.95 : 0.6))
                        }
                    }
                    .frame(width: 40, height: 54)
                    .background(.white.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(step == shot ? accent : .white.opacity(0.4),
                                    style: StrokeStyle(lineWidth: step == shot ? 2.5 : 1, dash: taken == nil && step != shot ? [4, 3] : []))
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if taken != nil {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white, accent)
                                .offset(x: 5, y: 5)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(taken == nil || camera.isCapturing)
                .accessibilityLabel(taken == nil ? Self.title(for: step) : L.f("scan.retake", Self.title(for: step)))
            }
        }
    }

    private func retake(_ step: KurswahlShot) {
        guard images[step] != nil, step != shot || images[step] != nil else { return }
        Haptics.light()
        camera.begin(step)
        announceStep()
    }

    // MARK: Controls

    private var controls: some View {
        HStack {
            Button {
                Haptics.light()
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel(L.s("scan.close"))

            Spacer()

            Button {
                Task { await shoot() }
            } label: {
                ZStack {
                    Circle().stroke(.white.opacity(0.35), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: camera.state.progress)
                        .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.12), value: camera.state.progress)
                    Circle()
                        .fill(.white)
                        .padding(8)
                        .scaleEffect(shutterDown ? 0.82 : 1)
                }
                .frame(width: 84, height: 84)
            }
            .buttonStyle(.plain)
            .disabled(camera.isCapturing || camera.authorization != .allowed)
            .accessibilityLabel(L.s("scan.shutter"))

            Spacer()

            Group {
                if camera.hasTorch {
                    Button {
                        Haptics.light()
                        camera.toggleTorch()
                    } label: {
                        Image(systemName: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(camera.torchOn ? .yellow : .white)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 56, height: 56)
                    }
                    .glassEffect(.regular.tint(camera.torchOn ? Color.yellow.opacity(0.25) : nil).interactive(), in: .circle)
                    .scaleEffect(hint == .tooDark && !camera.torchOn && !reduceMotion ? 1.12 : 1)
                    .animation(hint == .tooDark && !reduceMotion
                               ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default,
                               value: hint == .tooDark && !camera.torchOn)
                    .accessibilityLabel(L.s("scan.torch"))
                } else {
                    Color.clear.frame(width: 56, height: 56)
                }
            }
        }
        .padding(.horizontal, 28)
    }

    private func shoot() async {
        guard !camera.isCapturing, camera.authorization == .allowed else { return }
        let step = shot
        Haptics.success()
        withAnimation(.easeOut(duration: 0.08)) {
            flash = true
            shutterDown = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeOut(duration: 0.4)) {
                flash = false
                shutterDown = false
            }
        }
        guard let image = await camera.capture() else {
            Haptics.error()
            return
        }
        images[step] = image
        withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
            thumbnails[step] = Self.thumbnail(of: image)
        }
        // the next photo not taken yet, in order; all three taken → done
        let order = KurswahlShot.allCases
        let after = order.drop(while: { $0 != step }).dropFirst() + order
        if let next = after.first(where: { images[$0] == nil }) {
            Haptics.medium()
            camera.begin(next)
            announceStep()
        } else {
            camera.stop()
            onFinish(order.compactMap { images[$0] })
        }
    }

    private static func thumbnail(of image: CGImage) -> UIImage {
        let width: CGFloat = 120
        let height = width * CGFloat(image.height) / CGFloat(max(image.width, 1))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { _ in
            UIImage(cgImage: image).draw(in: CGRect(x: 0, y: 0, width: width, height: height))
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

// MARK: - Step diagram

/// A tiny A4 sheet with the table outline and the part the current photo should frame.
private struct StepDiagram: View {
    let shot: KurswahlShot
    let accent: Color

    var body: some View {
        let width: CGFloat = 26, height: CGFloat = 36
        let region = shot.region
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(.white.opacity(0.9))
            // title lines and the table
            VStack(alignment: .leading, spacing: 2) {
                Capsule().fill(.black.opacity(0.35)).frame(width: 12, height: 2)
                Capsule().fill(.black.opacity(0.2)).frame(width: 8, height: 2)
            }
            .offset(x: 3, y: 3)
            Rectangle()
                .stroke(.black.opacity(0.35), lineWidth: 0.75)
                .frame(width: width - 6, height: height * 0.64)
                .offset(x: 3, y: height * 0.28)
            RoundedRectangle(cornerRadius: 2)
                .fill(accent.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(accent, lineWidth: 1.5))
                .frame(width: width - 2, height: height * (region.upperBound - region.lowerBound))
                .offset(x: 1, y: height * region.lowerBound)
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
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

/// Half the table up close: about ten rows and the same columns, larger.
private struct CloseUpRows: Shape {
    var quad: QuadVector

    private static let rows: [Double] = stride(from: 0.0, through: 1.0, by: 0.1).map { $0 }
    private static let columns: [Double] = [0.0, 0.25, 0.33, 0.40, 0.46, 0.52, 0.58, 0.64, 0.70, 0.78, 1.0]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for v in Self.rows {
            path.move(to: quad.point(u: 0, v: v))
            path.addLine(to: quad.point(u: 1, v: v))
        }
        for u in Self.columns {
            path.move(to: quad.point(u: u, v: 0))
            path.addLine(to: quad.point(u: u, v: 1))
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
