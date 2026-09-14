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
    /// When reading started (the bar shows while set) and when the plan was ready.
    @State private var readingStart: Date?
    @State private var readingDone: Date?
    @State private var failure: String?
    @State private var draft: CustomPlanDraft?

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
        .overlay { if readingStart != nil { readingOverlay } }
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
                tip("paintpalette", L.s("custom.setup.tip.background"))
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
                .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L.s("custom.setup.a11y.result"))
                .accessibilityAddTraits(.isImage)
        }
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
        .disabled(readingStart != nil)
    }

    // MARK: Reading

    /// A plain screen with a native progress bar, redrawn every frame so it climbs smoothly.
    private var readingOverlay: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 18) {
                Text(L.s("custom.reading.title"))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                TimelineView(.animation) { timeline in
                    let progress = readingProgress(at: timeline.date)
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(accent)
                        .frame(maxWidth: 260)
                        .accessibilityValue(Text(verbatim: "\(Int((progress * 100).rounded())) %"))
                }
            }
            .padding(32)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    /// Linear to 90 % in six seconds while working; once done, eased up to 100 % in 0.35 s.
    private func readingProgress(at date: Date) -> Double {
        guard let start = readingStart else { return 0 }
        let climbed = { (moment: Date) in min(0.9, moment.timeIntervalSince(start) / 6 * 0.9) }
        guard let done = readingDone else { return climbed(date) }
        let from = climbed(done)
        let t = min(1, max(0, date.timeIntervalSince(done) / 0.35))
        return from + (1 - from) * (1 - pow(1 - t, 3))
    }

    private func read(_ images: [CGImage]) {
        guard !images.isEmpty else { return }
        finish { try await KurswahlScanner.read(images) }
    }

    /// Reads the photos, loads the Stufenplan meanwhile, then shows the review with the summary.
    /// The bar climbs to 90 % in about six seconds and only reaches 100 % once the plan is built.
    private func finish(_ scanned: @escaping @Sendable () async throws -> KurswahlScanner.Result) {
        readingDone = nil
        withAnimation { readingStart = Date() }
        Task {
            defer {
                withAnimation {
                    readingStart = nil
                    readingDone = nil
                }
            }
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
                let next = CustomPlanDraft(kurswahl: scan.kurswahl, loaded: loaded)
                readingDone = Date()
                try? await Task.sleep(for: .milliseconds(600))
                Haptics.success()
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
