// ============================================================
// FirestoreEventManager.swift
// Firestore CRUD with real-time listener for user events
// ============================================================

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class FirestoreEventManager: ObservableObject {
    
    @Published var userEvents: [FirestoreEvent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    deinit { listener?.remove() }
    
    // MARK: - Real-time listener for user's events
    func startListening(uid: String) {
        listener?.remove()
        isLoading = true
        listener = db.collection("events")
            .whereField("creatorUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    guard let snapshot else { return }
                    self.userEvents = snapshot.documents.compactMap { doc in
                        try? doc.data(as: FirestoreEvent.self)
                    }
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: - Create
    func createEvent(_ event: FirestoreEvent) async throws {
        var newEvent = event
        newEvent.createdAt = Timestamp(date: Date())
        try db.collection("events").addDocument(from: newEvent)
        successMessage = "Event created successfully!"
        HapticManager.notification(.success)
    }
    
    // MARK: - Update
    func updateEvent(_ event: FirestoreEvent) async throws {
        guard let id = event.id else { throw FirestoreError.missingID }
        try db.collection("events").document(id).setData(from: event, merge: true)
        successMessage = "Event updated successfully!"
        HapticManager.notification(.success)
    }
    
    // MARK: - Delete
    func deleteEvent(_ event: FirestoreEvent) async throws {
        guard let id = event.id else { throw FirestoreError.missingID }
        try await db.collection("events").document(id).delete()
        HapticManager.notification(.success)
    }
    
    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }
}

enum FirestoreError: LocalizedError {
    case missingID
    
    var errorDescription: String? {
        switch self {
        case .missingID: return "Event ID is missing. Please try again."
        }
    }
}
