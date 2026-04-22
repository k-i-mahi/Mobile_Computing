// ============================================================
// EventJSONViewModel.swift
// In-memory event store with search, filter, and sort
// ============================================================

import Foundation
import Combine

enum EventSortOption: String, CaseIterable, Identifiable {
    case dateAscending  = "Date: Soonest"
    case dateDescending = "Date: Latest"
    case nameAscending  = "Name: A→Z"
    case seatsAvailable = "Seats Available"

    var id: String { rawValue }
}

@MainActor
final class EventJSONViewModel: ObservableObject {

    @Published var allEvents: [Event] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    @Published var selectedCategory: String = "All"
    @Published var selectedSortOption: EventSortOption = .dateAscending

    var categories: [String] {
        let cats = Set(allEvents.map { $0.category })
        return ["All"] + cats.sorted()
    }

    var filteredEvents: [Event] {
        var result = allEvents

        if selectedCategory != "All" {
            result = result.filter { $0.category == selectedCategory }
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.venue.lowercased().contains(query) ||
                $0.organizerName.lowercased().contains(query) ||
                $0.description.lowercased().contains(query)
            }
        }

        switch selectedSortOption {
        case .dateAscending:
            result.sort { $0.date < $1.date }
        case .dateDescending:
            result.sort { $0.date > $1.date }
        case .nameAscending:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .seatsAvailable:
            result.sort { $0.seatsRemaining > $1.seatsRemaining }
        }

        return result
    }

    // MARK: - Actions

    func setEvents(_ events: [Event]) {
        allEvents = events
        isLoading = false
        errorMessage = nil
    }

    func clearEvents() {
        allEvents = []
        isLoading = true
    }

    func clearFilter() {
        selectedCategory = "All"
        searchText = ""
    }

    func loadEvents() {
        isLoading = true
        errorMessage = nil
    }
}
