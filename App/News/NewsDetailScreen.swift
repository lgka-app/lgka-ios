import SwiftUI
import LGKACore

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
    /// file-type glyph and size, websites a link glyph and their domain.
    private struct ActionLink: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let url: URL
        let symbol: String        // leading glyph
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
                              symbol: symbol(forFileType: dl.fileType), trailing: "arrow.down.circle")
        }

        static func website(_ link: NewsLink) -> ActionLink? {
            guard let url = URL(string: link.url) else { return nil }
            let host = url.host ?? link.url
            // no favicon service: that would send the reader's IP to a third party
            return ActionLink(id: "l:" + link.url, title: link.text, subtitle: host.replacingOccurrences(of: "www.", with: ""),
                              url: url, symbol: "link", trailing: "arrow.up.right.square")
        }
    }

    private func actionRow(_ button: ActionLink) -> some View {
        Link(destination: button.url) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.12))
                    Image(systemName: button.symbol).foregroundStyle(accent)
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
