// ============================================================
// NewsArticle.swift
// NewsAPI response models with robust decoding
// ============================================================

import Foundation

struct NewsArticle: Identifiable, Codable, Hashable {
    var id: String { url }
    let source: ArticleSource
    let author: String?
    let title: String
    let description: String?
    let url: String
    let urlToImage: String?
    let publishedAt: String
    let content: String?

    // MARK: - Display Helpers
    var displayAuthor: String { author ?? "Unknown Author" }
    var displayDescription: String { description ?? "No description available." }
    var displaySource: String { source.name }
    var stableId: String { url }
    
    var imageURL: URL? {
        guard let urlStr = urlToImage else { return nil }
        return URL(string: urlStr)
    }
    
    var articleURL: URL? { URL(string: url) }
    
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: publishedAt) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .none
            return display.string(from: date)
        }
        return publishedAt
    }
    
    var relativeDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: publishedAt) {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: Date())
        }
        return publishedAt
    }
    
    private enum CodingKeys: String, CodingKey {
        case source, author, title, description, url, urlToImage, publishedAt, content
    }
}

struct ArticleSource: Codable, Hashable {
    let id: String?
    let name: String
}

struct NewsResponse: Codable {
    let status: String
    let totalResults: Int?
    let articles: [NewsArticle]
    let message: String?
}
