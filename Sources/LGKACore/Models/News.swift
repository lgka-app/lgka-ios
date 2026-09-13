import Foundation

// MARK: - News

public struct NewsData: Codable, Hashable, Sendable {
    public var articles: [NewsArticle]

    public init(articles: [NewsArticle]) { self.articles = articles }
}

public struct NewsArticle: Codable, Hashable, Sendable, Identifiable {
    public var id: String { url }
    public var title: String
    public var author: String
    public var description: String
    public var content: String?
    public var htmlContent: String?
    /// As displayed, e.g. "09. September 2026".
    public var createdDate: String
    /// ISO-8601 when known.
    public var publishedAt: String?
    public var views: Int
    public var url: String
    public var links: [NewsLink]
    public var standaloneLinks: [NewsLink]
    public var images: [NewsImage]
    public var downloads: [NewsDownload]
    public var tags: [String]
}

public struct NewsLink: Codable, Hashable, Sendable {
    public var text: String
    public var url: String
}

public struct NewsImage: Codable, Hashable, Sendable {
    public var url: String
    public var thumbnailUrl: String?
    public var alt: String?
}

public struct NewsDownload: Codable, Hashable, Sendable {
    public var title: String
    public var url: String
    public var fileType: String
    public var size: String?
}
