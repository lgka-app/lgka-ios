import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreMotion
import QuartzCore
import SwiftUI
import Vision
import LGKAPlanKit

/// Live state of the Kurswahlprotokoll camera: permission, the detected sheet, the current
/// instruction and the capture. The AVFoundation work runs in `CameraPipeline`.
@Observable
@MainActor
final class KurswahlCamera {
    enum Authorization { case unknown, allowed, denied }

    private(set) var authorization: Authorization = .unknown
    /// The sheet in the latest analysed frame (0…1 of the portrait frame).
    private(set) var quad: ScanQuad?
    private(set) var state = ScanGuidance.State(hint: .noDocument, progress: 0, capture: false)
    /// Gravity across the screen (x right, y up), for the spirit level.
    private(set) var level = CGPoint.zero
    private(set) var torchOn = false
    private(set) var hasTorch = false
    private(set) var isCapturing = false
    /// Width / height of the analysed portrait frames.
    private(set) var frameAspect: CGFloat = 3.0 / 4.0

    /// Fires when the "ready" state held long enough.
    @ObservationIgnored var onAutoCapture: (() -> Void)?
    @ObservationIgnored let pipeline = CameraPipeline()
    @ObservationIgnored private var guidance = ScanGuidance()
    @ObservationIgnored private var stableQuad: ScanQuad?
    @ObservationIgnored private var running = false

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorization = .allowed
        case .notDetermined: authorization = await AVCaptureDevice.requestAccess(for: .video) ? .allowed : .denied
        default: authorization = .denied
        }
        guard authorization == .allowed, !running else { return }
        running = true
        pipeline.onFrame = { [weak self] result in
            Task { @MainActor in self?.handle(result) }
        }
        hasTorch = await pipeline.configure()
        pipeline.start()
    }

    func stop() {
        running = false
        torchOn = false
        pipeline.stop()
    }

    func toggleTorch() {
        torchOn.toggle()
        pipeline.setTorch(torchOn)
    }

    /// Takes a few photos in a row and straightens each with the last stable detection. The scanner
    /// merges them cell by cell, so a digit blurred or glared in one photo is read from another.
    func capture(count: Int = 3) async -> [CGImage] {
        guard !isCapturing else { return [] }
        isCapturing = true
        defer {
            isCapturing = false
            guidance.reset()
        }
        let quad = stableQuad ?? self.quad
        var images: [CGImage] = []
        for _ in 0..<count {
            let data: Data? = await withCheckedContinuation { continuation in
                pipeline.capture { continuation.resume(returning: $0) }
            }
            guard let data else { continue }
            let image = await Task.detached(priority: .userInitiated) { () -> CGImage? in
                // 4032 px keeps three photos in memory; the table crops are enlarged again for reading
                guard let image = KurswahlScanner.image(from: data, maxPixels: 4032) else { return nil }
                return SheetCorrection.corrected(image, quad: quad)
            }.value
            if let image { images.append(image) }
        }
        return images
    }

    private func handle(_ result: CameraPipeline.FrameResult) {
        guard running, !isCapturing else { return }
        frameAspect = result.aspect
        level = CGPoint(x: result.gravityX, y: result.gravityY)
        quad = result.frame.quad
        let next = guidance.update(result.frame)
        if next.hint == .ready, let q = result.frame.quad { stableQuad = q }
        state = next
        if next.capture { onAutoCapture?() }
    }
}

/// Session, live analysis (sheet outline, brightness, glare, motion) and photo capture.
/// Session state lives on `sessionQueue`, analysis state on `analysisQueue`.
final class CameraPipeline: NSObject, @unchecked Sendable, AVCaptureVideoDataOutputSampleBufferDelegate {
    struct FrameResult: Sendable {
        var frame: ScanFrame
        var gravityX: Double
        var gravityY: Double
        var aspect: Double
    }

    let session = AVCaptureSession()
    var onFrame: (@Sendable (FrameResult) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.lgka.scan.session")
    private let analysisQueue = DispatchQueue(label: "com.lgka.scan.analysis")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private let motionLock = NSLock()

    private var device: AVCaptureDevice?
    private var configured = false
    private var photoDelegates: [Int64: PhotoDelegate] = [:]
    private var lastAnalysis: CFTimeInterval = 0
    private var previousQuad: ScanQuad?
    private var motion = (tilt: 0.0, shake: 0.0, gx: 0.0, gy: 0.0)

    /// Returns whether the camera has a torch.
    func configure() async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in continuation.resume(returning: configureSession()) }
        }
    }

    private func configureSession() -> Bool {
        if configured { return device?.hasTorch ?? false }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        // virtual multi-camera devices switch to the ultra wide (macro) at close range on their own
        let types: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .back)
        guard let device = types.lazy.compactMap({ type in discovery.devices.first { $0.deviceType == type } }).first,
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return false }
        session.addInput(input)
        if (try? device.lockForConfiguration()) != nil {
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
            device.unlockForConfiguration()
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            if let largest = device.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }) {
                photoOutput.maxPhotoDimensions = largest
            }
        }
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: analysisQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        for connection in [videoOutput.connection(with: .video), photoOutput.connection(with: .video)].compactMap({ $0 })
        where connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        self.device = device
        configured = true
        return device.hasTorch
    }

    func start() {
        sessionQueue.async { [self] in
            if !session.isRunning { session.startRunning() }
        }
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 20
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] data, _ in
            guard let self, let data else { return }
            let g = data.gravity
            // lying flat over a table, the phone's back points straight down: gravity z = -1
            let tilt = acos(max(-1, min(1, -g.z))) * 180 / .pi
            let r = data.rotationRate, a = data.userAcceleration
            let shake = (r.x * r.x + r.y * r.y + r.z * r.z).squareRoot() + 2 * (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            motionLock.lock()
            motion = (tilt, shake, g.x, g.y)
            motionLock.unlock()
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        sessionQueue.async { [self] in
            if let device, device.hasTorch, (try? device.lockForConfiguration()) != nil {
                device.torchMode = .off
                device.unlockForConfiguration()
            }
            if session.isRunning { session.stopRunning() }
        }
    }

    func setTorch(_ on: Bool) {
        sessionQueue.async { [self] in
            guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
            if on { try? device.setTorchModeOn(level: 0.6) } else { device.torchMode = .off }
            device.unlockForConfiguration()
        }
    }

    func capture(_ completion: @escaping @Sendable (Data?) -> Void) {
        sessionQueue.async { [self] in
            guard session.isRunning else { completion(nil); return }
            let settings = AVCapturePhotoSettings()
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
            settings.photoQualityPrioritization = .quality
            let id = settings.uniqueID
            let delegate = PhotoDelegate { [weak self] data in
                completion(data)
                guard let self else { return }
                sessionQueue.async { self.photoDelegates[id] = nil }
            }
            photoDelegates[id] = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    // MARK: Live analysis (~9 frames a second)

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastAnalysis >= 0.11, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysis = now

        let quad = Self.detectSheet(in: buffer)
        let (luma, glare) = Self.brightness(of: buffer, in: quad)
        let jitter: Double = switch (quad, previousQuad) {
        case let (q?, p?): q.jitter(from: p)
        case (.some, nil): 1 // a sheet that just appeared is not steady yet
        default: 0
        }
        previousQuad = quad
        motionLock.lock()
        let m = motion
        motionLock.unlock()

        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let frame = ScanFrame(quad: quad, luma: luma, glare: glare, tilt: m.tilt, motion: m.shake, jitter: jitter, time: now)
        onFrame?(FrameResult(frame: frame, gravityX: m.gx, gravityY: m.gy,
                             aspect: height > 0 ? Double(width) / Double(height) : 0.75))
    }

    private static func detectSheet(in buffer: CVPixelBuffer) -> ScanQuad? {
        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        guard (try? handler.perform([request])) != nil,
              let sheet = request.results?.first, sheet.confidence > 0.6 else { return nil }
        // Vision: 0…1, origin bottom-left
        func point(_ p: CGPoint) -> ScanPoint { ScanPoint(x: p.x, y: 1 - p.y) }
        return ScanQuad(topLeft: point(sheet.topLeft), topRight: point(sheet.topRight),
                        bottomRight: point(sheet.bottomRight), bottomLeft: point(sheet.bottomLeft))
    }

    /// Mean luma 0…1 and the share of clipped white pixels, inside the sheet's bounding box when found.
    private static func brightness(of buffer: CVPixelBuffer, in quad: ScanQuad?) -> (Double, Double) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard CVPixelBufferGetPlaneCount(buffer) > 0, let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return (0.5, 0) }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0), height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        var x0 = 0, x1 = width, y0 = 0, y1 = height
        if let quad {
            let xs = quad.corners.map(\.x), ys = quad.corners.map(\.y)
            x0 = max(0, Int((xs.min() ?? 0) * Double(width)))
            x1 = min(width, Int((xs.max() ?? 1) * Double(width)))
            y0 = max(0, Int((ys.min() ?? 0) * Double(height)))
            y1 = min(height, Int((ys.max() ?? 1) * Double(height)))
        }
        guard x1 > x0, y1 > y0 else { return (0.5, 0) }
        let step = max(4, min(x1 - x0, y1 - y0) / 90)
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        var sum = 0, clipped = 0, count = 0
        for y in stride(from: y0, to: y1, by: step) {
            for x in stride(from: x0, to: x1, by: step) {
                let value = Int(pixels[y * rowBytes + x])
                sum += value
                if value >= 250 { clipped += 1 }
                count += 1
            }
        }
        guard count > 0 else { return (0.5, 0) }
        return (Double(sum) / Double(count) / 255, Double(clipped) / Double(count))
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Data?) -> Void

    init(completion: @escaping @Sendable (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        completion(error == nil ? photo.fileDataRepresentation() : nil)
    }
}

/// Straightens the photographed sheet to a flat rectangle.
enum SheetCorrection {
    static func corrected(_ image: CGImage, quad: ScanQuad?) -> CGImage {
        guard let quad else { return image }
        let input = CIImage(cgImage: image)
        let width = input.extent.width, height = input.extent.height
        // a little margin so the sheet's printed border survives the crop
        let cx = quad.corners.map(\.x).reduce(0, +) / 4, cy = quad.corners.map(\.y).reduce(0, +) / 4
        func point(_ p: ScanPoint) -> CGPoint {
            let x = cx + (p.x - cx) * 1.02, y = cy + (p.y - cy) * 1.02
            return CGPoint(x: min(max(x, 0), 1) * width, y: (1 - min(max(y, 0), 1)) * height)
        }
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = input
        filter.topLeft = point(quad.topLeft)
        filter.topRight = point(quad.topRight)
        filter.bottomRight = point(quad.bottomRight)
        filter.bottomLeft = point(quad.bottomLeft)
        guard let output = filter.outputImage,
              let result = CIContext().createCGImage(output, from: output.extent) else { return image }
        return result
    }
}
