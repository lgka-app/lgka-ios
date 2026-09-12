import SwiftUI
import QuickLook
import LGKACore

/// News list — mirrors news_screen.dart. Navigation is value-based on the
/// article itself (stable id = url), so a refresh while a detail is open
/// can never index out of range.
struct NewsListScreen: View {
    @Environment(HomeModel.self) private var model

    var body: some View {
        Group {
            if let articles = model.newsList {
                if articles.isEmpty {
                    ContentUnavailableView(L.s("noNewsAvailable"), systemImage: "newspaper")
                } else {
                    // news_screen.dart parity: one card per article, not a grouped list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(articles) { article in
                                NavigationLink(value: article) {
                                    NewsCard(article: article)
                                }
                                .buttonStyle(.plain)
                                .tapHaptic()
                                .accessibilityIdentifier("news.row")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .readableWidth()
                    }
                    .background(Color.appBackground)
                }
            } else if model.newsFailed {
                ContentUnavailableView {
                    Label(L.s("serverConnectionFailed"), systemImage: "wifi.exclamationmark")
                } actions: {
                    Button(L.s("tryAgain")) { Haptics.light(); Task { await model.sync(only: [.news]) } }
                        .buttonStyle(.bordered)
                }
            } else {
                ProgressView()
            }
        }
        .themeBg()
        .navigationTitle(L.s("news"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: NewsArticle.self) { article in
            NewsDetailScreen(article: article)
        }
        .task { if model.newsList == nil { await model.sync(only: [.news]) } }
        .refreshable { Haptics.medium(); await model.sync(only: [.news]) }
    }
}

struct NewsCard: View {
    let article: NewsArticle
    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(article.title)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "newspaper.fill")
                    .font(.body)
                    .foregroundStyle(accent)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 12) {
                Text(article.createdDate).fontWeight(.medium)
                Label("\(article.views)", systemImage: "eye")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            if !article.description.isEmpty {
                Text(article.description)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 12)
            }
            if !article.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(article.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(accent.opacity(0.3)))
                            .foregroundStyle(accent)
                    }
                }
                .padding(.top, 12)
            }
            Label(article.author, systemImage: "person")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.top, 16)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Wrapping row (Flutter `Wrap` parity) for tag chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, origin) in arrange(proposal: proposal, subviews: subviews).origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return (CGSize(width: width, height: y + rowHeight), origins)
    }
}

/// News detail — mirrors news_detail_screen.dart: content with tappable
/// links, images, download + standalone-link buttons, open-in-browser. The
/// full article arrives with the sync, so there is nothing to load here.
struct NewsDetailScreen: View {
    let article: NewsArticle
    @Environment(HomeModel.self) private var model
    @State private var photo: PhotoItem?
    @Environment(\.appAccent) private var accent

    var body: some View {
        content(article)
            .themeBg()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let url = URL(string: article.url) {
                        Link(destination: url) {
                            Label(L.s("openInBrowser"), systemImage: "safari")
                        }
                    }
                }
            }
            .sheet(item: $photo) { PhotoViewer(item: $0) } // sheet: swipe down dismisses like Photos
    }

    /// A download or standalone link row (news_detail_screen parity): downloads show a
    /// file-type glyph and size, websites their favicon and domain.
    private struct ActionLink: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let url: URL
        let symbol: String        // leading glyph (or fallback behind the favicon)
        let favicon: URL?         // websites only
        let trailing: String      // "arrow.down.circle" / "arrow.up.right.square"

        /// Flutter `_getFileTypeIcon` mapping onto SF Symbols.
        static func symbol(forFileType type: String) -> String {
            switch type.lowercased() {
            case "audio", "sound": return "headphones"
            case "video", "movie": return "video"
            case "image", "picture", "photo": return "photo"
            case "pdf", "document": return "doc.richtext"
            case "archive", "zip", "rar": return "archivebox"
            case "text": return "doc.plaintext"
            case "spreadsheet", "excel": return "tablecells"
            case "presentation", "powerpoint": return "rectangle.on.rectangle.angled"
            default: return "arrow.down.doc"
            }
        }

        static func download(_ dl: NewsDownload) -> ActionLink? {
            guard let url = URL(string: dl.url) else { return nil }
            return ActionLink(id: "d:" + dl.url, title: dl.title, subtitle: dl.size, url: url,
                              symbol: symbol(forFileType: dl.fileType), favicon: nil, trailing: "arrow.down.circle")
        }

        static func website(_ link: NewsLink) -> ActionLink? {
            guard let url = URL(string: link.url) else { return nil }
            let host = url.host ?? link.url
            let favicon = url.host.flatMap { URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\($0)") }
            return ActionLink(id: "l:" + link.url, title: link.text, subtitle: host.replacingOccurrences(of: "www.", with: ""),
                              url: url, symbol: "link", favicon: favicon, trailing: "arrow.up.right.square")
        }
    }

    private func actionRow(_ button: ActionLink) -> some View {
        Link(destination: button.url) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.12))
                    if let favicon = button.favicon {
                        AsyncImage(url: favicon) { image in
                            image.resizable().scaledToFit().padding(9)
                        } placeholder: {
                            Image(systemName: button.symbol).foregroundStyle(accent)
                        }
                    } else {
                        Image(systemName: button.symbol).foregroundStyle(accent)
                    }
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(button.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let subtitle = button.subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: button.trailing).foregroundStyle(accent)
            }
            .padding(14)
            .frame(minHeight: 44)
            .surfaceCard(radius: 12)
        }
        .foregroundStyle(.primary)
    }

    private func content(_ article: NewsArticle) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title).font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { metaLabels }
                    VStack(alignment: .leading, spacing: 4) { metaLabels }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let text = article.content, !text.isEmpty {
                    linkedText(text, links: article.links)
                }

                ForEach(article.images, id: \.url) { image in
                    if let url = URL(string: image.url) {
                        // tap → full-screen, zoomable photo viewer
                        Button {
                            Haptics.light()
                            photo = PhotoItem(url: url, alt: image.alt ?? article.title)
                        } label: {
                            AsyncImage(url: url) { img in
                                img.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.quaternary)
                                    .frame(height: 180)
                                    .overlay(ProgressView())
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(image.alt ?? article.title)
                        .accessibilityHint(L.s("a11y.openPhoto"))
                    }
                }

                let buttons: [ActionLink] = article.downloads.compactMap(ActionLink.download)
                    + article.standaloneLinks.compactMap(ActionLink.website)
                if !buttons.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(buttons) { actionRow($0) }
                    }
                }

                // "Weitere Neuigkeiten" — recommended articles (news_detail parity)
                if let all = model.newsList {
                    let others = all.filter { $0.url != article.url }.prefix(3)
                    if !others.isEmpty {
                        Divider().padding(.top, 8)
                        Text(L.s("weitereNeuigkeiten"))
                            .font(.title3.bold())
                            .accessibilityAddTraits(.isHeader)
                        // the same cards as the news list, not bare titles
                        ForEach(Array(others)) { other in
                            NavigationLink(value: other) {
                                NewsCard(article: other)
                            }
                            .tapHaptic()
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .readableWidth()
            .padding(20)
        }
        .accessibilityIdentifier("news.detail")
    }

    @ViewBuilder private var metaLabels: some View {
        Label(article.author, systemImage: "person")
        Label(article.createdDate, systemImage: "calendar")
        Label("\(article.views) \(L.s("views"))", systemImage: "eye")
    }

    /// Renders content with embedded links tappable (AttributedString).
    private func linkedText(_ text: String, links: [NewsLink]) -> some View {
        var attributed = AttributedString(text)
        for link in links {
            guard let url = URL(string: link.url),
                  let range = attributed.range(of: link.text) else { continue }
            attributed[range].link = url
            attributed[range].foregroundColor = accent
            attributed[range].underlineStyle = .single
        }
        return Text(attributed)
            .font(.body)
            .textSelection(.enabled)
    }
}

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
