import SwiftUI
import LGKACore

struct NewsView: View {
    var body: some View {
        NavigationStack {
            LoadableView(load: { try await SchoolAPI.newsList() }) { articles in
                List(articles.indices, id: \.self) { i in
                    let md = articles[i]
                    NavigationLink(value: i) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(md.title).font(.headline)
                            if !md.description.isEmpty {
                                Text(md.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            HStack(spacing: 12) {
                                Label(md.author, systemImage: "person")
                                Label(md.createdDate, systemImage: "calendar")
                            }
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .navigationDestination(for: Int.self) { i in
                    NewsDetailView(metadata: articles[i])
                }
            }
            .navigationTitle("News")
        }
    }
}

struct NewsDetailView: View {
    let metadata: NewsParser.Metadata

    var body: some View {
        LoadableView(load: { try await SchoolAPI.article(url: metadata.url) }) { article in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(metadata.title)
                        .font(.title2.bold())
                    HStack(spacing: 12) {
                        Label(metadata.author, systemImage: "person")
                        Label(metadata.createdDate, systemImage: "calendar")
                        Label("\(metadata.views)", systemImage: "eye")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let content = article.content, !content.isEmpty {
                        Text(content)
                            .font(.body)
                            .textSelection(.enabled)
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

                    let buttons = article.standaloneLinks + article.downloads.map {
                        ["text": ($0["title"] as? String) ?? "Download",
                         "url": ($0["url"] as? String) ?? ""]
                    }
                    if !buttons.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(buttons.indices, id: \.self) { i in
                                if let url = URL(string: buttons[i]["url"] ?? "") {
                                    Link(destination: url) {
                                        Label(buttons[i]["text"] ?? "Link",
                                              systemImage: "arrow.up.right.square")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.glass)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
