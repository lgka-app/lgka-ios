import SwiftUI
import LGKACore

/// News list — mirrors news_screen.dart.
struct NewsListScreen: View {
    @State private var articles: [NewsParser.Metadata]?
    @State private var failed = false

    var body: some View {
        Group {
            if let articles {
                if articles.isEmpty {
                    ContentUnavailableView(L.s("noNewsAvailable"), systemImage: "newspaper")
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(articles.indices, id: \.self) { i in
                                NavigationLink(value: i) {
                                    NewsCard(md: articles[i])
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .navigationDestination(for: Int.self) { i in
                        NewsDetailScreen(md: articles[i])
                    }
                }
            } else if failed {
                ContentUnavailableView {
                    Label(L.s("serverConnectionFailed"), systemImage: "wifi.exclamationmark")
                } actions: {
                    Button(L.s("tryAgain")) { failed = false; Task { await load() } }
                        .buttonStyle(.bordered)
                }
            } else {
                ProgressView()
            }
        }
        .themeBg()
        .navigationTitle(L.s("news"))
        .navigationBarTitleDisplayMode(.inline)
        .task { if articles == nil { await load() } }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            articles = try await SchoolAPI.newsList()
        } catch {
            if articles == nil { failed = true }
        }
    }
}

struct NewsCard: View {
    let md: NewsParser.Metadata

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(md.title).font(.callout.weight(.semibold))
                .multilineTextAlignment(.leading)
            if !md.description.isEmpty {
                Text(md.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            HStack(spacing: 12) {
                Label(md.author, systemImage: "person")
                Label(md.createdDate, systemImage: "calendar")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}

/// News detail — mirrors news_detail_screen.dart: content with tappable
/// links, images, download + standalone-link buttons, open-in-browser.
struct NewsDetailScreen: View {
    let md: NewsParser.Metadata
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
                    Button(L.s("tryAgain")) { failed = false; Task { await load() } }
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
                    Link(destination: url) { Image(systemName: "safari") }
                }
            }
        }
        .task { if article == nil { await load() } }
    }

    private func load() async {
        do {
            article = try await SchoolAPI.article(url: md.url)
        } catch {
            failed = true
        }
    }

    private func content(_ article: NewsParser.Article) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(md.title).font(.title2.bold())
                HStack(spacing: 12) {
                    Label(md.author, systemImage: "person")
                    Label(md.createdDate, systemImage: "calendar")
                    Label("\(md.views)", systemImage: "eye")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let text = article.content, !text.isEmpty {
                    linkedText(text, links: article.links)
                }

                ForEach(article.images.indices, id: \.self) { i in
                    if let urlString = article.images[i]["url"] as? String,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.quaternary)
                                .frame(height: 180)
                                .overlay(ProgressView())
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                let buttons: [(String, String, String)] =
                    article.standaloneLinks.compactMap { link in
                        guard let text = link["text"], let url = link["url"] else { return nil }
                        return (text, url, "arrow.up.right.square")
                    } + article.downloads.compactMap { dl in
                        guard let title = dl["title"] as? String,
                              let url = dl["url"] as? String else { return nil }
                        return (title, url, "arrow.down.circle")
                    }
                if !buttons.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(buttons.indices, id: \.self) { i in
                            if let url = URL(string: buttons[i].1) {
                                Link(destination: url) {
                                    HStack {
                                        Image(systemName: buttons[i].2)
                                        Text(buttons[i].0).lineLimit(1)
                                        Spacer()
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .padding(14)
                                    .surfaceCard(radius: 12)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    /// Renders content with embedded links tappable (AttributedString).
    private func linkedText(_ text: String, links: [[String: String]]) -> some View {
        var attributed = AttributedString(text)
        for link in links {
            guard let linkText = link["text"], let urlString = link["url"],
                  let url = URL(string: urlString),
                  let range = attributed.range(of: linkText) else { continue }
            attributed[range].link = url
            attributed[range].foregroundColor = accent
            attributed[range].underlineStyle = .single
        }
        return Text(attributed)
            .font(.body)
            .textSelection(.enabled)
    }
}
