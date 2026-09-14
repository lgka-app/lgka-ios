import ARKit
import AVFoundation
import RealityKit
import SwiftUI
import LGKACore
import LGKAPlanKit

/// Live state of a scan: what the tracker publishes, plus the counter and when things lit up.
@Observable
@MainActor
final class LiveScanModel {
    struct PinnedMark: Sendable, Equatable {
        var x: Double
        var y: Double
        var text: String
        var kind: ScanProgress.Mark.Kind
        var seenAt: Double
    }

    enum Authorization { case unknown, allowed, denied }

    private(set) var authorization: Authorization = .unknown
    private(set) var camera: CameraSnapshot?
    private(set) var quad: [CGPoint]?
    private(set) var sheet: SheetFrame?
    private(set) var hint: SheetTracker.TrackingHint?
    /// Nil until the first frame was read.
    private(set) var progress: ScanProgress?
    var hours: Int { progress?.hours ?? 0 }
    private(set) var coverage = [Float](repeating: 0, count: SheetTracker.columns * SheetTracker.rows)
    /// When each cell first counted as scanned (for the flash).
    private(set) var cellLitAt = [Double](repeating: 0, count: SheetTracker.columns * SheetTracker.rows)
    private(set) var marks: [PinnedMark] = []
    private(set) var finished = false
    private(set) var torchOn = false
    private(set) var hasTorch = false

    @ObservationIgnored let tracker: SheetTracker
    @ObservationIgnored private var boxes: [TextBox] = []
    @ObservationIgnored private var aspect = 297.0 / 210.0
    @ObservationIgnored private var session: ARSession?
    @ObservationIgnored private var completeSince: Date?

    init(schuljahr: String?, halbjahr: String) {
        tracker = SheetTracker(schuljahr: schuljahr, halbjahr: halbjahr)
    }

    func attach(_ session: ARSession) {
        self.session = session
        session.delegateQueue = tracker.frameQueue
        session.delegate = tracker
        tracker.onUpdate = { [weak self] update in
            Task { @MainActor in self?.apply(update) }
        }
        tracker.onReading = { [weak self] reading in
            Task { @MainActor in self?.apply(reading) }
        }
    }

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorization = .allowed
        case .notDetermined: authorization = await AVCaptureDevice.requestAccess(for: .video) ? .allowed : .denied
        default: authorization = .denied
        }
        guard authorization == .allowed, let session, ARWorldTrackingConfiguration.isSupported else { return }
        session.run(SheetTracker.configuration(), options: [.resetTracking, .removeExistingAnchors])
        hasTorch = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera?.hasTorch ?? false
    }

    func stop() {
        if torchOn { toggleTorch() }
        session?.pause()
    }

    func toggleTorch() {
        guard let device = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera, device.hasTorch,
              (try? device.lockForConfiguration()) != nil else { return }
        torchOn.toggle()
        if torchOn { try? device.setTorchModeOn(level: 0.6) } else { device.torchMode = .off }
        device.unlockForConfiguration()
    }

    /// The scan so far, for the review screen; nil until a table was recognised.
    var result: KurswahlScanner.Result? {
        guard let kurswahl = progress?.kurswahl else { return nil }
        return KurswahlScanner.Result(kurswahl: kurswahl, boxes: boxes, aspect: aspect)
    }

    /// True once the sheet's sum has matched the hours read for a second.
    var completeLongEnough: Bool {
        guard let completeSince else { return false }
        return Date().timeIntervalSince(completeSince) >= 1
    }

    func markFinished() { finished = true }

    private func apply(_ update: SheetTracker.Update) {
        guard !finished else { return }
        camera = update.camera
        quad = update.quad
        if sheet == nil, update.sheet != nil { Haptics.medium() }
        sheet = update.sheet
        hint = update.hint
    }

    private func apply(_ reading: SheetTracker.Reading) {
        guard !finished else { return }
        let now = Date.timeIntervalSinceReferenceDate
        for i in reading.coverage.indices where reading.coverage[i] >= 0.5 && coverage[i] < 0.5 {
            cellLitAt[i] = now
        }
        coverage = reading.coverage
        boxes = reading.boxes
        aspect = reading.aspect

        var next: [PinnedMark] = []
        for mark in reading.progress.marks {
            // a value already pinned keeps its first time, so only new readings pop
            let known = marks.first { $0.kind == mark.kind && $0.text == mark.text && abs($0.x - mark.x) < 0.015 && abs($0.y - mark.y) < 0.008 }
            next.append(PinnedMark(x: mark.x, y: mark.y, text: mark.text, kind: mark.kind, seenAt: known?.seenAt ?? now))
        }
        marks = next

        if reading.progress.hours > hours { Haptics.light() }
        progress = reading.progress
        if reading.progress.complete {
            if completeSince == nil { completeSince = Date() }
        } else {
            completeSince = nil
        }
    }
}

/// Scans a Kurswahlprotokoll while the phone moves over it: the paper is fixed in space, scanned
/// parts light up on it, read values pop up where they are printed, and the counter climbs to the
/// sheet's own sum. Finishes on its own once the sum matches.
struct KurswahlLiveScanScreen: View {
    let schuljahr: String?
    let halbjahr: String
    let onFinish: (KurswahlScanner.Result) -> Void
    let onCancel: () -> Void

    @Environment(\.appAccent) private var accent
    @Environment(\.openURL) private var openURL
    @State private var model: LiveScanModel
    @State private var announcedHours = 0

    init(schuljahr: String?, halbjahr: String, onFinish: @escaping (KurswahlScanner.Result) -> Void, onCancel: @escaping () -> Void) {
        self.schuljahr = schuljahr
        self.halbjahr = halbjahr
        self.onFinish = onFinish
        self.onCancel = onCancel
        _model = State(initialValue: LiveScanModel(schuljahr: schuljahr, halbjahr: halbjahr))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if model.authorization == .denied {
                permissionView
            } else {
                GeometryReader { geometry in
                    ARCameraView(model: model)
                        .onAppear { model.tracker.setViewport(geometry.size) }
                        .onChange(of: geometry.size) { _, size in model.tracker.setViewport(size) }
                }
                .ignoresSafeArea()
                ScanPaintView(model: model).ignoresSafeArea()
                controls
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .task { await model.start() }
        .task {
            // auto-finish once the counter has matched the sum for a second
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                if model.completeLongEnough, !model.finished { finish() }
            }
        }
        .onDisappear { model.stop() }
        .onChange(of: model.hours) { _, hours in
            // announce sparingly: every five hours
            if hours >= announcedHours + 5 {
                announcedHours = hours
                AccessibilityNotification.Announcement(L.f("scan.live.a11y.hours", hours)).post()
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    Haptics.light()
                    onCancel()
                } label: {
                    Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel(L.s("scan.close"))
                Spacer()
                if model.hasTorch {
                    Button {
                        Haptics.light()
                        model.toggleTorch()
                    } label: {
                        Image(systemName: model.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.body.weight(.semibold)).frame(width: 44, height: 44)
                    }
                    .glassEffect(.regular.tint(model.torchOn ? Color.yellow.opacity(0.25) : nil).interactive(), in: .circle)
                    .accessibilityLabel(L.s("scan.torch"))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            Text(hintText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .glassEffect(.regular, in: .capsule)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: hintText)
                .padding(.bottom, 12)

            counter
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }

    private var hintText: String {
        if model.finished || model.progress?.complete == true { return L.s("scan.live.complete") }
        switch model.hint {
        case .moreLight: return L.s("scan.live.moreLight")
        case .slower: return L.s("scan.live.slower")
        case nil: return L.s("scan.live.move")
        }
    }

    private var counter: some View {
        let hours = model.hours
        let sum = model.progress?.sum
        let subjects = model.progress?.subjects ?? 0
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if let sum {
                        Text(L.f("scan.live.hoursOf", hours, sum))
                    } else {
                        Text(L.f("scan.live.hours", hours))
                    }
                }
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(hours)))
                .animation(.snappy, value: hours)
                Text(sum == nil && hours > 0 ? L.s("scan.live.noSum") : L.f("scan.live.subjects", subjects))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: subjects)
            }
            .foregroundStyle(.white)
            .accessibilityElement(children: .combine)
            Spacer()
            if model.finished {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else if hours > 0 {
                Button {
                    finish()
                } label: {
                    Text(L.s("scan.live.done")).font(.headline).padding(.horizontal, 8).frame(minHeight: 36)
                }
                .buttonStyle(.glassProminent)
                .tint(accent)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
        .glassEffect(.regular.tint(model.finished ? Color.green.opacity(0.2) : nil), in: .rect(cornerRadius: 24))
        .animation(.spring(duration: 0.35), value: model.finished)
        .animation(.spring(duration: 0.35), value: hours > 0)
    }

    private func finish() {
        guard !model.finished, let result = model.result else { return }
        model.markFinished()
        Haptics.success()
        AccessibilityNotification.Announcement(L.s("scan.live.complete")).post()
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            model.stop()
            onFinish(result)
        }
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill").font(.system(size: 44)).foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)
            Text(L.s("scan.permission.title")).font(.title3.weight(.semibold)).foregroundStyle(.white)
            Text(L.s("scan.permission.body")).font(.callout).foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Button(L.s("scan.permission.settings")) {
                Haptics.light()
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.glassProminent)
            .tint(accent)
            Button(L.s("scan.close")) {
                Haptics.light()
                onCancel()
            }
            .foregroundStyle(.white)
        }
        .padding(32)
    }
}

/// The camera feed of the AR session (RealityKit draws nothing else; the paint is a SwiftUI layer).
private struct ARCameraView: UIViewRepresentable {
    let model: LiveScanModel

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR, .disablePersonOcclusion, .disableGroundingShadows]
        model.attach(view.session)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {}

    static func dismantleUIView(_ view: ARView, coordinator: ()) {
        view.session.pause()
    }
}
