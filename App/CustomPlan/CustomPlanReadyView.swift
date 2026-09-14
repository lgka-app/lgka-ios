import SwiftUI
import PDFKit
import LGKACore

/// Shown right after saving, like unwrapping a present: the new plan's first page as a thumbnail
/// in the middle of the screen. A tap sets off a burst of haptics and the thumbnail morphs into the
/// PDF viewer with the system zoom transition (and back into the thumbnail when the viewer closes).
struct CustomPlanReadyView: View {
    let saved: SavedCustomPlan
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var morph
    @State private var file: URL?
    @State private var thumbnail: UIImage?
    @State private var appeared = false
    @State private var showViewer = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(L.s("custom.ready.title"))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                thumbnailView
                    .aspectRatio(297 / 210, contentMode: .fit)
                    .frame(maxWidth: 520)
                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                    .matchedTransitionSource(id: "plan", in: morph)
                    .shadow(color: .black.opacity(0.22), radius: 22, y: 12)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .opacity(appeared ? 1 : 0)
                Text(L.s("custom.ready.tap"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
        }
        .contentShape(Rectangle())
        .onTapGesture { open() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.s("custom.ready.a11y"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open() }
        .task { await prepare() }
        // closing the viewer goes straight home: Home is put back underneath the moment the viewer
        // starts to close, instead of first returning here
        .onChange(of: showViewer) { wasShown, isShown in
            if wasShown && !isShown { onFinished() }
        }
        .fullScreenCover(isPresented: $showViewer) {
            if let file {
                PdfViewerScreen(fileUrl: file, title: L.s("custom.home.title"), targetPage: nil)
                    .navigationTransition(.zoom(sourceID: "plan", in: morph))
            }
        }
    }

    private var thumbnailView: some View {
        ZStack {
            Color.white
            if let thumbnail {
                Image(uiImage: thumbnail).resizable().scaledToFit()
            } else {
                ProgressView()
            }
        }
    }

    private func prepare() async {
        guard file == nil, let url = try? CustomPlanSource.pdfFile(for: saved.plan) else { return }
        file = url
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let page = PDFDocument(url: url)?.page(at: 0) else { return nil }
            return page.thumbnail(of: CGSize(width: 1600, height: 1132), for: .mediaBox)
        }.value
        thumbnail = image
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.25)) { appeared = true }
    }

    private func open() {
        guard appeared, !showViewer, file != nil else { return }
        // a burst: one strong hit, then three quick ticks while the page morphs open
        Haptics.success()
        Task {
            for _ in 0..<3 {
                try? await Task.sleep(for: .milliseconds(60))
                Haptics.light()
            }
        }
        showViewer = true
    }
}
