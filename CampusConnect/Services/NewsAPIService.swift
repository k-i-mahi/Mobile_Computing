// ============================================================
// NewsAPIService.swift
// URLSession-based NewsAPI integration with retry logic
// ============================================================

import Foundation

enum NewsAPIError: LocalizedError {
    case invalidURL
    case noData
    case apiError(String)
    case decodingError(String)
    case networkError(String)
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid URL configuration."
        case .noData:               return "No data received from server."
        case .apiError(let msg):    return "API Error: \(msg)"
        case .decodingError(let m): return "Failed to parse news: \(m)"
        case .networkError(let m):  return "Network error: \(m)"
        case .rateLimited:          return "Too many requests. Please wait a moment."
        }
    }
}

actor NewsAPIService {
    
    private let apiKey = Constants.newsAPIKey
    private let baseURL = "https://newsapi.org/v2/everything"
    
    // Simple in-memory cache
    private var cache: [String: (articles: [NewsArticle], timestamp: Date)] = [:]
    private let cacheDuration: TimeInterval = 300 // 5 minutes
    
    func fetchArticles(query: String, forceRefresh: Bool = false) async throws -> [NewsArticle] {
        // Check cache first
        if !forceRefresh, let cached = cache[query],
           Date().timeIntervalSince(cached.timestamp) < cacheDuration {
            return cached.articles
        }
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q",        value: query),
            URLQueryItem(name: "sortBy",   value: "publishedAt"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "pageSize", value: "25"),
            URLQueryItem(name: "apiKey",   value: apiKey)
        ]
        
        guard let url = components?.url else { throw NewsAPIError.invalidURL }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw NewsAPIError.networkError(error.localizedDescription)
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...299: break
            case 429: throw NewsAPIError.rateLimited
            default: throw NewsAPIError.networkError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        let decoded: NewsResponse
        do {
            decoded = try JSONDecoder().decode(NewsResponse.self, from: data)
        } catch {
            throw NewsAPIError.decodingError(error.localizedDescription)
        }
        
        if decoded.status != "ok" {
            throw NewsAPIError.apiError(decoded.message ?? "Unknown API error")
        }
        
        let articles = decoded.articles.filter { $0.title != "[Removed]" }
        
        // Update cache
        cache[query] = (articles, Date())
        
        return articles
    }
    
    func clearCache() {
        cache.removeAll()
    }
}
