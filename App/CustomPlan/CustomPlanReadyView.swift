import SwiftUI
import PDFKit
import LGKACore

/// Shown right after saving, like unwrapping a present: the new plan's first page as a thumbnail
/// in the middle of the screen. A tap sets off a burst of haptics, the thumbnail grows until it
/// fills the screen the way the viewer shows the page, and the viewer takes over in place.
struct CustomPlanReadyView: View {
    let saved: SavedCustomPlan
    let onFinished: () -> Void

    @Environment(\.appAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var file: URL?
    @State private var thumbnail: UIImage?
    @State private var appeared = false
    @State private var expanding = false
    @State private var showViewer = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text(L.s("custom.ready.title"))
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .opacity(expanding ? 0 : 1)
                    Color.clear
                        .frame(width: cardWidth(geo), height: cardWidth(geo) * 210 / 297)
                    Text(L.s("custom.ready.tap"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(expanding ? 0 : 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                thumbnailView
                    .frame(width: expanding ? geo.size.width : cardWidth(geo),
                           height: (expanding ? geo.size.width : cardWidth(geo)) * 210 / 297)
                    .clipShape(.rect(cornerRadius: expanding ? 0 : 12, style: .continuous))
                    .shadow(color: .black.opacity(expanding ? 0 : 0.22), radius: 22, y: 12)
                    // grows towards where the viewer puts the page: full width, just under the navigation bar
                    .position(x: geo.size.width / 2,
                              y: expanding ? geo.safeAreaInsets.top + 60 + geo.size.width * 210 / 297 / 2 : geo.size.height / 2)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .opacity(appeared ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { open() }
        }
        .ignoresSafeArea(edges: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.s("custom.ready.a11y"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open() }
        .task { await prepare() }
        .fullScreenCover(isPresented: $showViewer, onDismiss: onFinished) {
            if let file {
                PdfViewerScreen(fileUrl: file, title: L.s("custom.home.title"), targetPage: nil)
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

    private func cardWidth(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.width * 0.86, 520)
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
        guard appeared, !expanding, file != nil else { return }
        // a burst: one strong hit, then three quick ticks
        Haptics.success()
        Task {
            for _ in 0..<3 {
                try? await Task.sleep(for: .milliseconds(60))
                Haptics.light()
            }
        }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.12)) { expanding = true }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 220 : 470))
            // the viewer appears in place of the grown page, without the usual slide up
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { showViewer = true }
        }
    }
}
