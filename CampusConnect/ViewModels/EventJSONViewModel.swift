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
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    let categories = ["All", "Academic", "Sports", "Cultural", "Tech", "Workshop", "Social"]
    
    init() {
        loadEvents()
    }
    
    // MARK: - Load from bundle
    func loadEvents() {
        isLoading = true
        errorMessage = nil
        do {
            allEvents = try Bundle.main.decode([Event].self, from: "events.json")
            filteredEvents = allEvents
        } catch {
            errorMessage = "Failed to load events: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - Filter + Search
    func applyFilter() {
        var result = allEvents
        
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
