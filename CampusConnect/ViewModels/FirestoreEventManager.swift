// ============================================================
// FirestoreEventManager.swift
// Real-time Firestore event CRUD with live snapshot listeners
// ============================================================

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class FirestoreEventManager: ObservableObject {

    @Published var allEvents: [FirestoreEvent] = []
    @Published var myEvents: [FirestoreEvent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var allEventsListener: ListenerRegistration?
    private var myEventsListener: ListenerRegistration?
    private let db = Firestore.firestore()

    deinit {
        allEventsListener?.remove()
        myEventsListener?.remove()
    }

    // MARK: - Listen All Events

    func startListeningAllEvents(uid: String?) {
        allEventsListener?.remove()
        isLoading = true
        allEventsListener = db.collection("events")
            .whereField("status", isEqualTo: "approved")
            .order(by: "date", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.allEvents = snapshot?.documents.compactMap {
                        try? $0.data(as: FirestoreEvent.self)
                    } ?? []
                }
            }
    }

    func stopListeningAllEvents() {
        allEventsListener?.remove()
        allEventsListener = nil
    }

    // MARK: - My Events

    func startListeningMyEvents(uid: String) {
        myEventsListener?.remove()
        myEventsListener = db.collection("events")
            .whereField("creatorUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.myEvents = snapshot?.documents.compactMap {
                        try? $0.data(as: FirestoreEvent.self)
                    } ?? []
                }
            }
    }

    // MARK: - Create

    func createEvent(_ event: FirestoreEvent) async throws {
        try db.collection("events").addDocument(from: event)
        HapticManager.notification(.success)
    }

    // MARK: - Update

    func updateEvent(_ event: FirestoreEvent) async throws {
        guard let id = event.id else { throw FirestoreError.missingID }
        try db.collection("events").document(id).setData(from: event, merge: true)
        HapticManager.notification(.success)
    }

    // MARK: - Delete

    func deleteEvent(id: String) async throws {
        try await db.collection("events").document(id).delete()
        HapticManager.notification(.success)
    }

    // MARK: - Fetch single

    func fetchEvent(id: String) async throws -> FirestoreEvent {
        let snapshot = try await db.collection("events").document(id).getDocument()
        guard let event = try? snapshot.data(as: FirestoreEvent.self) else {
            throw FirestoreError.missingID
        }
        return event
    }
}

// MARK: - FirestoreError

enum FirestoreError: Error, LocalizedError {
    case missingID
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingID:       return "Event ID is missing."
        case .decodingFailed:  return "Failed to decode event data."
        }
    }
}

// MARK: - FirestoreEvent Model

struct FirestoreEvent: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var category: String
    var venue: String
    var date: Timestamp
    var endDate: Timestamp?
    var organizerName: String
    var creatorUid: String
    var status: String
    var maxSeats: Int
    var rsvpCount: Int
    var imageURL: String?
    var tags: [String]
    var createdAt: Timestamp
    var updatedAt: Timestamp?

    var asEvent: Event {
        Event(
            id: id ?? UUID().uuidString,
            title: title,
            description: description,
            category: category,
            venue: venue,
            date: date.dateValue(),
            endDate: endDate?.dateValue(),
            organizerName: organizerName,
            creatorUid: creatorUid,
            status: status,
            maxSeats: maxSeats,
            rsvpCount: rsvpCount,
            imageURL: imageURL,
            tags: tags
        )
    }
}

// MARK: - Event (Local model)

struct Event: Identifiable, Hashable {
    let id: String
    var title: String
    var description: String
    var category: String
    var venue: String
    var date: Date
    var endDate: Date?
    var organizerName: String
    var creatorUid: String
    var status: String
    var maxSeats: Int
    var rsvpCount: Int
    var imageURL: String?
    var tags: [String]

    var seatsRemaining: Int { max(0, maxSeats - rsvpCount) }
    var isFull: Bool { seatsRemaining == 0 }
}
