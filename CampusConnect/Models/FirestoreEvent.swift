// ============================================================
// FirestoreEvent.swift
// Firestore-backed event model for user-created events
// ============================================================

import Foundation
import FirebaseFirestore

struct FirestoreEvent: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var venue: String
    var date: String
    var category: String
    var creatorUid: String
    var creatorEmail: String
    var createdAt: Timestamp?
    var seats: Int?
    var tags: [String]?

    // MARK: – Computed Properties

    /// Formatted display date (e.g. "Jan 15, 2025 at 7:00 PM")
    var formattedDate: String {
        DateFormatterHelper.display(from: date) ?? date
    }

    /// Short date (e.g. "Jan 15, 2025")
    var shortDate: String {
        DateFormatterHelper.shortDisplay(from: date) ?? date
    }

    /// Whether the event is in the future
    var isUpcoming: Bool {
        DateFormatterHelper.isUpcoming(date)
    }

    /// Day and month tuple for calendar cards — always returns a value
    var dayMonth: (day: String, month: String) {
        if let dm = DateFormatterHelper.dayMonth(from: date) {
            return dm
        }
        return ("--", "---")
    }

    /// First letter of the creator's email for avatar display
    var creatorInitial: String {
        String(creatorEmail.prefix(1)).uppercased()
    }

    // MARK: – Memberwise Init

    init(
        id: String? = nil,
        title: String,
        description: String,
        venue: String,
        date: String,
        category: String,
        creatorUid: String,
        creatorEmail: String,
        createdAt: Timestamp? = nil,
        seats: Int? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.venue = venue
        self.date = date
        self.category = category
        self.creatorUid = creatorUid
        self.creatorEmail = creatorEmail
        self.createdAt = createdAt
        self.seats = seats
        self.tags = tags
    }
}