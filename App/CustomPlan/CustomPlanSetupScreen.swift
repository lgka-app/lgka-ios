import SwiftUI
import LGKACore
import LGKAPlanKit

/// Explains the custom timetable in three steps (what you need, how to take the photo, what you
/// get), then scans the sheet with the automatic camera.
struct CustomPlanSetupScreen: View {
    /// When set, the host shows the review; otherwise this screen pushes it itself.
    var onDraft: ((CustomPlanDraft) -> Void)?
    var onDone: (() -> Void)?
    @Environment(HomeModel.self) private var model
    @Environment(\.appAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCamera = false
    @State private var reading: UIImage?
    @State private var failure: String?
    @State private var draft: CustomPlanDraft?
    @State private var sweep = false
    /// The example result shown large (tap to open, tap to close; no zoom or panning).
    @State private var resultExpanded = false
    @Namespace private var resultSpace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                needSection
                photoSection
                resultSection
                Label(L.s("custom.setup.privacy"), systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .readableWidth()
        }
        .background(Color.appBackground)
        .navigationTitle(L.s("custom.title"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { actions }
        .overlay { if resultExpanded { expandedResult } }
        .overlay { if let reading { readingOverlay(reading) } }
        .fullScreenCover(isPresented: $showCamera) {
            KurswahlCameraScreen(onCapture: { images in
                showCamera = false
                read(images)
            }, onCancel: { showCamera = false })
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

    // MARK: 1 · What you need

    private var needSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(L.s("custom.setup.needTitle"), body: L.s("custom.setup.needBody"))
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(accent.opacity(0.08))
                TutorialImage(name: TutorialImages.sample, aspect: 210 / 297)
                    .frame(maxWidth: 200)
                    .clipShape(.rect(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.08), lineWidth: 0.5))
                    // on top of the clipped sheet, so a long label may reach onto the card instead of being cut
                    .overlay { callouts }
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 10)
                    .rotationEffect(.degrees(reduceMotion ? 0 : -2.5))
                    .padding(.vertical, 22)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.s("custom.setup.a11y.sample"))
            .accessibilityAddTraits(.isImage)
        }
    }

    /// Where the scan reads on the sample sheet (fractions of the image).
    private var callouts: some View {
        GeometryReader { geo in
            callout(L.s("custom.setup.callout.subjects"), at: CGPoint(x: 0.33, y: 0.48), in: geo.size)
            callout(L.s("custom.setup.callout.hours"), at: CGPoint(x: 0.64, y: 0.33), in: geo.size)
            callout(L.s("custom.setup.callout.sums"), at: CGPoint(x: 0.64, y: 0.915), in: geo.size)
        }
        .accessibilityHidden(true)
    }

    private func callout(_ text: String, at point: CGPoint, in size: CGSize) -> some View {
        // keep the whole pill on the card: its centre moves in so neither end sticks out past the sheet
        // by more than the card's margin, however long the label is in either language
        let maxWidth = size.width + 36
        let estimated = min(maxWidth, CGFloat(text.count) * 6.4 + 14)
        let x = min(max(point.x * size.width, estimated / 2 - 18), size.width + 18 - estimated / 2)
        return Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(accent, in: .capsule)
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .frame(maxWidth: maxWidth)
            .fixedSize()
            .position(x: x, y: point.y * size.height)
    }

    // MARK: 2 · How to take the photo

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
                tip("camera.badge.clock", L.s("custom.setup.tip.auto"))
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

    // MARK: 3 · What you get

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(L.s("custom.setup.resultTitle"), body: L.s("custom.setup.resultBody"))
            TutorialImage(name: TutorialImages.result, aspect: 297 / 210, symbol: "tablecells")
                .clipShape(.rect(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.black.opacity(0.08), lineWidth: 0.5))
                .matchedGeometryEffect(id: "result", in: resultSpace, isSource: !resultExpanded)
                .opacity(resultExpanded ? 0 : 1)
                .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.light()
                    withAnimation(.spring(duration: 0.4, bounce: 0.15)) { resultExpanded = true }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L.s("custom.setup.a11y.result"))
                .accessibilityAddTraits([.isImage, .isButton])
        }
    }

    /// The example result enlarged over a dark background; any tap closes it.
    private var expandedResult: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .transition(.opacity)
            TutorialImage(name: TutorialImages.result, aspect: 297 / 210, symbol: "tablecells")
                .clipShape(.rect(cornerRadius: 10, style: .continuous))
                .matchedGeometryEffect(id: "result", in: resultSpace, isSource: resultExpanded)
                .padding(.horizontal, 12)
                .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
                .readableWidth()
            VStack {
                HStack {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular, in: .circle)
                        .accessibilityLabel(L.s("a11y.close"))
                        .accessibilityAddTraits(.isButton)
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.light()
            withAnimation(.spring(duration: 0.35, bounce: 0.1)) { resultExpanded = false }
        }
        .accessibilityAction(.escape) { resultExpanded = false }
    }

    private func sectionHeader(_ title: String, body: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
