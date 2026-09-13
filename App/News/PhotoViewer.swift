import SwiftUI
import QuickLook

struct PhotoItem: Identifiable {
    let url: URL
    let alt: String
    var id: String { url.absoluteString }
}

/// Photos open in the system Quick Look viewer (pinch/double-tap zoom, share,
/// swipe down or Done to dismiss) — the native iOS photo experience.
struct PhotoViewer: View {
    let item: PhotoItem
    @Environment(\.dismiss) private var dismiss
    @State private var file: URL?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let file {
                QuickLookView(file: file, title: item.alt) { dismiss() }
                    .ignoresSafeArea()
            } else if failed {
                ContentUnavailableView(L.s("errorLoading"), systemImage: "photo")
                    .foregroundStyle(.white)
                    .onTapGesture { dismiss() }
            } else {
                ProgressView().tint(.white)
            }
        }
        .task {
            if let cached = await Self.download(item.url) { file = cached } else { failed = true }
        }
    }

    private static func download(_ url: URL) async -> URL? {
        guard let (data, response) = try? await URLSession.shared.data(from: url) else { return nil }
        let ext = (response as? HTTPURLResponse)?.mimeType == "image/png" ? "png"
            : (url.pathExtension.isEmpty ? "jpg" : url.pathExtension)
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("photo_\(url.absoluteString.hashValue.magnitude).\(ext)")
        return (try? data.write(to: dest, options: .atomic)) == nil ? nil : dest
    }
}

/// QLPreviewController inside a navigation controller so its native Done button
/// and swipe-to-dismiss both end the SwiftUI presentation.
struct QuickLookView: UIViewControllerRepresentable {
    let file: URL
    let title: String
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        preview.delegate = context.coordinator
        preview.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .done, primaryAction: UIAction { _ in Haptics.light(); onDismiss() })
        let nav = UINavigationController(rootViewController: preview)
        nav.navigationBar.prefersLargeTitles = false
        return nav
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(file: file, title: title) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        private let item: PreviewItem
        init(file: URL, title: String) { item = PreviewItem(url: file, title: title) }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem { item }
    }

    final class PreviewItem: NSObject, QLPreviewItem {
        let previewItemURL: URL?
        let previewItemTitle: String?
        init(url: URL, title: String) { previewItemURL = url; previewItemTitle = title }
    }
}
