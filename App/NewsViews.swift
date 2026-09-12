import SwiftUI
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
                            ForEach(articles) { md in
                                NavigationLink(value: md) {
                                    NewsCard(md: md)
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
                    Button(L.s("tryAgain")) { Haptics.light(); Task { await model.loadNews(mode: .refresh) } }
                        .buttonStyle(.bordered)
                }
            } else {
                ProgressView()
            }
        }
        .themeBg()
        .navigationTitle(L.s("news"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: NewsParser.Metadata.self) { md in
            NewsDetailScreen(md: md)
        }
        .task { if model.newsList == nil { await model.loadNews() } }
        .refreshable { Haptics.medium(); await model.loadNews(mode: .refresh) }
    }
}

struct NewsCard: View {
    let md: NewsParser.Metadata
    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(md.title)
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
                Text(md.createdDate).fontWeight(.medium)
                Label("\(md.views)", systemImage: "eye")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            if !md.description.isEmpty {
                Text(md.description)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 12)
            }
            if !md.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(md.tags, id: \.self) { tag in
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
            HStack(spacing: 8) {
                Label(md.author, systemImage: "person")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    Text(L.s("mehrErfahren"))
                    Image(systemName: "arrow.right")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            }
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
/// links, images, download + standalone-link buttons, open-in-browser.
struct NewsDetailScreen: View {
    let md: NewsParser.Metadata
    @Environment(HomeModel.self) private var model
    @State private var article: NewsParser.Article?
    @State private var failed = false
    @Environment(\.appAccent) private var accent

    var body: some View {
        Group {
            if let article {
                content(article)
            } else if failed {
                ContentUnavailableView {
                    Label(L.s("serverConnectionFailed"), systemImage: "wifi.exclamationmark")
                } actions: {
                    Button(L.s("tryAgain")) { Haptics.light(); failed = false; Task { await load() } }
                        .buttonStyle(.bordered)
                }
            } else {
                ProgressView()
            }
        }
        .themeBg()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let url = URL(string: md.url) {
                    Link(destination: url) {
                        Label(L.s("openInBrowser"), systemImage: "safari")
                    }
                }
            }
        }
        .task(id: md.url) { if article == nil { await load() } }
    }

    private func load() async {
        do {
            article = try await SchoolAPI.article(url: md.url)
        } catch {
            failed = true
        }
    }

    private struct ActionLink: Identifiable {
        let id: String
        let title: String
        let url: URL
        let symbol: String
    }

    private func content(_ article: NewsParser.Article) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(md.title).font(.title2.bold())
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
                        AsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.quaternary)
                                .frame(height: 180)
                                .overlay(ProgressView())
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityLabel(image.alt ?? md.title)
                    }
                }

                let buttons: [ActionLink] =
                    article.standaloneLinks.compactMap { link in
                        URL(string: link.url).map {
                            ActionLink(id: "l:" + link.url, title: link.text, url: $0,
                                       symbol: "arrow.up.right.square")
                        }
                    } + article.downloads.compactMap { dl in
                        URL(string: dl.url).map {
                            ActionLink(id: "d:" + dl.url, title: dl.title, url: $0,
                                       symbol: "arrow.down.circle")
                        }
                    }
                if !buttons.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(buttons) { button in
                            Link(destination: button.url) {
                                HStack {
                                    Image(systemName: button.symbol)
                                    Text(button.title).lineLimit(1)
                                    Spacer()
                                }
                                .font(.subheadline.weight(.medium))
                                .padding(14)
                                .frame(minHeight: 44)
                                .surfaceCard(radius: 12)
                            }
                        }
                    }
                }

                // "Weitere Neuigkeiten" — recommended articles (news_detail parity)
                if let all = model.newsList {
                    let others = all.filter { $0.url != md.url }.prefix(3)
                    if !others.isEmpty {
                        Divider().padding(.top, 8)
                        Text(L.s("weitereNeuigkeiten"))
                            .font(.title3.bold())
                            .accessibilityAddTraits(.isHeader)
                        ForEach(Array(others)) { other in
                            NavigationLink(value: other) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(other.title)
                                        .font(.subheadline.weight(.semibold))
                                        .multilineTextAlignment(.leading)
                                    Text("\(other.author) · \(other.createdDate)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .surfaceCard(radius: 12)
                                .contentShape(Rectangle())
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
        Label(md.author, systemImage: "person")
        Label(md.createdDate, systemImage: "calendar")
        Label("\(md.views) \(L.s("views"))", systemImage: "eye")
    }

    /// Renders content with embedded links tappable (AttributedString).
    private func linkedText(_ text: String, links: [NewsParser.Link]) -> some View {
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
