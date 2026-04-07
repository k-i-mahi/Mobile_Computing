// ============================================================
// Event.swift
// Local JSON-backed event model
// ============================================================

import Foundation

struct Event: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String?
    let venue: String
    let date: String
    let category: String
    let organizerName: String
    let organizerRole: String
    let imageName: String?
    let seats: Int?
    let tags: [String]?
    
    // MARK: - Computed Properties
    var formattedDate: String {
        DateFormatterHelper.display(from: date) ?? date
    }
    
    var shortDate: String {
        DateFormatterHelper.shortDisplay(from: date) ?? date
    }
    
    var isUpcoming: Bool {
        DateFormatterHelper.isUpcoming(date)
    }
    
    var daysUntil: Int? {
        DateFormatterHelper.daysUntil(date)
    }
    
    var dayMonth: (day: String, month: String)? {
        DateFormatterHelper.dayMonth(from: date)
    }
    
    var relativeDate: String {
        DateFormatterHelper.relativeDisplay(from: date) ?? date
    }
    
    var displayDescription: String {
        description ?? "No description available."
    }
    
    var seatLabel: String? {
        guard let seats else { return nil }
        return "\(seats) seats"
    }
    
    // Build Organizer from embedded fields
    var organizer: Organizer {
        Organizer(
            name: organizerName,
            role: organizerRole,
            department: "Campus Events Office",
            email: "\(organizerName.lowercased().replacingOccurrences(of: " ", with: "."))@campus.edu",
            phone: nil,
            bio: "Dedicated to creating memorable campus experiences.",
            imageName: nil
        )
    }
}
