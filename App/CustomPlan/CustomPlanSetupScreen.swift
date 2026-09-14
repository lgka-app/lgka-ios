import SwiftUI
import PhotosUI
import LGKACore
import LGKAPlanKit

/// Explains the custom timetable: what a Kurswahlprotokoll looks like, what makes a good photo, then
/// scans it (automatic camera) or reads a picked photo.
struct CustomPlanSetupScreen: View {
    /// When set, the host shows the review; otherwise this screen pushes it itself.
    var onDraft: ((CustomPlanDraft) -> Void)?
    var onDone: (() -> Void)?
    @Environment(HomeModel.self) private var model
    @Environment(\.appAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCamera = false
    @State private var showSample = false
    @State private var photoItem: PhotosPickerItem?
    @State private var reading: UIImage?
    @State private var failure: String?
    @State private var draft: CustomPlanDraft?
    @State private var sweep = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                hero
                sampleSection
                photoSection
                stepsSection
                Label(L.s("custom.setup.privacy"), systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .surfaceCard()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .readableWidth()
        }
        .background(Color.appBackground)
        .navigationTitle(L.s("custom.title"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { actions }
        .overlay { if let reading { readingOverlay(reading) } }
        .fullScreenCover(isPresented: $showCamera) {
            KurswahlCameraScreen(onCapture: { images in
                showCamera = false
                read(images)
            }, onCancel: { showCamera = false })
        }
        .sheet(isPresented: $showSample) {
            TutorialImageViewer(name: TutorialImages.sample, label: L.s("custom.setup.a11y.sample"))
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = KurswahlScanner.image(from: data) else {
                    failure = L.s("custom.error.photo")
                    return
                }
                read([image])
            }
        }
        .navigationDestination(item: $draft) { draft in
            CustomPlanReviewScreen(draft: draft) { value in
                CustomPlanStore.shared.save(value)
                self.draft = nil
                onDone?()
            }
        }
        .alert(failure ?? "", isPresented: .init(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) { Haptics.light() }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(accent)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 80, height: 80)
                .glassEffect(.regular.tint(accent.opacity(0.12)), in: .rect(cornerRadius: 24))
                .accessibilityHidden(true)
            Text(L.s("custom.setup.title"))
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text(L.s("custom.setup.subtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: Sample sheet

    private var sampleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(L.s("custom.setup.needTitle"), body: L.s("custom.setup.needBody"))
            Button {
                Haptics.light()
                showSample = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(accent.opacity(0.08))
                    TutorialImage(name: TutorialImages.sample, aspect: 210 / 297)
                        .frame(maxWidth: 190)
                        .overlay { callouts }
                        .clipShape(.rect(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.08), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.18), radius: 16, y: 10)
                        .rotationEffect(.degrees(reduceMotion ? 0 : -2.5))
                        .padding(.vertical, 22)
                }
                .overlay(alignment: .bottomTrailing) {
                    Label(L.s("custom.setup.sampleHint"), systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                        .padding(10)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.s("custom.setup.a11y.sample"))
            .accessibilityHint(L.s("custom.setup.sampleHint"))
        }
    }

    /// Approximate spots of what the scan reads on the sample sheet (fractions of the image).
    private var callouts: some View {
        GeometryReader { geo in
            callout(L.s("custom.setup.callout.subjects"), at: CGPoint(x: 0.33, y: 0.47), in: geo.size)
            callout(L.s("custom.setup.callout.hours"), at: CGPoint(x: 0.62, y: 0.265), in: geo.size)
            callout(L.s("custom.setup.callout.sums"), at: CGPoint(x: 0.36, y: 0.93), in: geo.size)
        }
        .accessibilityHidden(true)
    }

    private func callout(_ text: String, at point: CGPoint, in size: CGSize) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(accent, in: .capsule)
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .fixedSize()
            .position(x: point.x * size.width, y: point.y * size.height)
    }

    // MARK: Photo examples

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(L.s("custom.setup.photoTitle"), body: nil)
            HStack(spacing: 12) {
                example(TutorialImages.good, good: true)
                example(TutorialImages.bad, good: false)
            }
            VStack(alignment: .leading, spacing: 12) {
                tip("rectangle.portrait.on.rectangle.portrait", L.s("custom.setup.tip.flat"))
                tip("viewfinder", L.s("custom.setup.tip.whole"))
                tip("flashlight.on.fill", L.s("custom.setup.tip.light"))
                tip("camera.shutter.button", L.s("custom.setup.tip.still"))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard()
        }
    }

    private func example(_ name: String, good: Bool) -> some View {
        VStack(spacing: 8) {
            TutorialImage(name: name, aspect: 4 / 5, symbol: good ? "photo" : "photo.badge.exclamationmark")
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(good ? Color.green : Color.red, lineWidth: 2)
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: good ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, good ? Color.green : Color.red)
                        .padding(8)
                        .shadow(color: .black.opacity(0.25), radius: 3)
                }
            Text(L.s(good ? "custom.setup.good" : "custom.setup.bad"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(good ? Color.green : Color.red)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.s(good ? "custom.setup.a11y.good" : "custom.setup.a11y.bad"))
        .accessibilityAddTraits(.isImage)
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 26)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(L.s("custom.setup.stepsTitle"), body: nil)
            VStack(alignment: .leading, spacing: 16) {
                step(1, L.s("custom.setup.step1"))
                step(2, L.s("custom.setup.step2"))
                step(3, L.s("custom.setup.step3"))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard()
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(accent.opacity(0.14), in: .circle)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(number). \(text)")
    }

    private func sectionHeader(_ title: String, body: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if let body {
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.medium()
                showCamera = true
            } label: {
                Label(L.s("custom.setup.scan"), systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.glassProminent)
            .tint(accent)
            .accessibilityIdentifier("customPlan.scan")
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(L.s("custom.setup.pick"), systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.glass)
            .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background {
            // content scrolls under the buttons without its text showing through
            LinearGradient(stops: [.init(color: Color.appBackground.opacity(0), location: 0),
                                   .init(color: Color.appBackground, location: 0.35)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .disabled(reading != nil)
    }

    // MARK: Reading

    private func readingOverlay(_ image: UIImage) -> some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 22) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 300)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay {
                        // a light sweeping over the sheet while it is being read
                        GeometryReader { geo in
                            LinearGradient(colors: [.clear, accent.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 60)
                                .offset(y: sweep ? geo.size.height - 30 : -30)
                        }
                        .clipShape(.rect(cornerRadius: 14))
                        .allowsHitTesting(false)
                        .opacity(reduceMotion ? 0 : 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { sweep = true }
                    }
                VStack(spacing: 6) {
                    Text(L.s("custom.reading.title")).font(.headline)
                    Text(L.s("custom.reading.subtitle")).font(.footnote).foregroundStyle(.secondary)
                }
                ProgressView()
            }
            .padding(32)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    private func read(_ images: [CGImage]) {
        guard let first = images.first else { return }
        withAnimation { reading = UIImage(cgImage: first) }
        sweep = false
        finish { try await KurswahlScanner.read(images) }
    }

    /// Reads the photos, loads the Stufenplan meanwhile, then shows the review.
    private func finish(_ scanned: @escaping @Sendable () async throws -> KurswahlScanner.Result) {
        Task {
            defer { withAnimation { reading = nil } }
            do {
                async let plans = CustomPlanSource.plans(model: model)
                let scan = try await scanned()
                let published = try await plans
                guard let loaded = CustomPlanSource.pick(published, stufe: nil, kurswahl: scan.kurswahl)
                        ?? CustomPlanSource.pick(published, stufe: nil, kurswahl: nil) else {
                    throw CustomPlanSource.Failure.noPlanPublished
                }
                #if DEBUG
                CustomPlanDebug.keep(scan)
                #endif
                Haptics.success()
                let next = CustomPlanDraft(kurswahl: scan.kurswahl, loaded: loaded)
                if let onDraft { onDraft(next) } else { draft = next }
            } catch is KurswahlParser.Failure {
                Haptics.error()
                failure = L.s("custom.error.notASheet")
            } catch CustomPlanSource.Failure.noPlanPublished {
                Haptics.error()
                failure = L.s("custom.error.noPlan")
            } catch {
                Haptics.error()
                failure = L.s("custom.error.generic")
            }
        }
    }
}
