// ============================================================
// EventJSONViewModel.swift
// Loads local JSON events with filtering, search, and sorting
// ============================================================

import Foundation
import Combine

@MainActor
final class EventJSONViewModel: ObservableObject {
    
    @Published var allEvents: [Event] = []
    @Published var filteredEvents: [Event] = []
    @Published var searchText: String = "" {
        didSet { applyFilter() }
    }
    @Published var selectedCategory: String = "All" {
        didSet { applyFilter() }
    }
    @Published var selectedSortOption: EventSortOption = .newest {
        didSet { applyFilter() }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    let categories = ["All", "Academic", "Sports", "Cultural", "Tech", "Workshop", "Social"]
    
    init() {
        // Don't auto-load JSON — DashboardView will feed Firestore data
    }
    
    // MARK: - Load from bundle (fallback)
    func loadEvents() {
        clearEvents()
        isLoading = false
    }
    
    // MARK: - Set events from Firestore
    func setEvents(_ events: [Event]) {
        allEvents = events
        applyFilter()
        isLoading = false
        errorMessage = nil
    }

    func clearEvents() {
        allEvents = []
        filteredEvents = []
        isLoading = false
        errorMessage = nil
    }
    
    // MARK: - Filter + Search
    func applyFilter() {
        var result = allEvents.filter { $0.status == .approved }
        
        if selectedCategory != "All" {
            result = result.filter { $0.category.lowercased() == selectedCategory.lowercased() }
        }
        
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                ($0.description?.lowercased().contains(query) ?? false) ||
                $0.venue.lowercased().contains(query) ||
                $0.organizerName.lowercased().contains(query) ||
                ($0.tags?.contains(where: { $0.lowercased().contains(query) }) ?? false)
            }
        }
        
        switch selectedSortOption {
        case .newest:
            result = result.sorted {
                let lhsCreated = $0.createdAtUnix ?? DateFormatterHelper.date(from: $0.date)?.timeIntervalSince1970 ?? 0
                let rhsCreated = $1.createdAtUnix ?? DateFormatterHelper.date(from: $1.date)?.timeIntervalSince1970 ?? 0
                return lhsCreated > rhsCreated
            }
        case .trending:
            result = result.sorted { ($0.upvoteCount + $0.commentCount) > ($1.upvoteCount + $1.commentCount) }
        case .mostUpvoted:
            result = result.sorted { $0.upvoteCount > $1.upvoteCount }
        case .mostDiscussed:
            result = result.sorted { $0.commentCount > $1.commentCount }
        case .nearestUpcoming:
            result = result.sorted {
                let lhsDate = DateFormatterHelper.date(from: $0.date) ?? .distantFuture
                let rhsDate = DateFormatterHelper.date(from: $1.date) ?? .distantFuture
                return lhsDate < rhsDate
            }
        }

        filteredEvents = result
    }
    
    // MARK: - Derived Data
    var upcomingEvents: [Event] {
        allEvents.filter { $0.isUpcoming }.prefix(5).map { $0 }
    }
    
    var eventsByDate: [String: [Event]] {
        Dictionary(grouping: allEvents, by: { $0.date })
    }
    
    var sortedDateKeys: [String] {
        eventsByDate.keys.sorted()
    }
    
    var eventCountByCategory: [(category: String, count: Int)] {
        Constants.eventCategories.map { cat in
            (cat, allEvents.filter { $0.category == cat }.count)
        }
    }
    
    var totalSeats: Int {
        allEvents.compactMap(\.seats).reduce(0, +)
    }
    
    func clearFilter() {
        searchText = ""
        selectedCategory = "All"
    }
}
