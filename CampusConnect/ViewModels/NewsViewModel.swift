// ============================================================
// NewsViewModel.swift
// Manages NewsAPI fetching with pull-to-refresh support
// ============================================================

import Foundation

@MainActor
final class NewsViewModel: ObservableObject {
    
    @Published var articles: [NewsArticle] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastRefreshed: Date?
    
    private let service = NewsAPIService()
    
    init() {
        Task { await fetchNews() }
    }
    
    func fetchNews(query: String = "campus events technology", forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            articles = try await service.fetchArticles(query: query, forceRefresh: forceRefresh)
            lastRefreshed = Date()
        } catch let error as NewsAPIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to load news: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func refresh() {
        Task { await fetchNews(forceRefresh: true) }
    }
    
    var lastRefreshedText: String? {
        guard let lastRefreshed else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: lastRefreshed, relativeTo: Date()))"
    }
}
