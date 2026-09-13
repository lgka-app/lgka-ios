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
