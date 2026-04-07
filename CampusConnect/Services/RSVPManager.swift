// ============================================================
// RSVPManager.swift
// Firestore RSVP subcollection management with real-time sync
// ============================================================

import Foundation
import FirebaseFirestore

struct RSVPRecord: Codable {
    var uid: String
    var userEmail: String
    var eventId: String
    var timestamp: Timestamp
}

@MainActor
final class RSVPManager: ObservableObject {
    
    @Published var rsvpedEventIds: Set<String> = []
    @Published var rsvpCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var countListener: ListenerRegistration?
    
    deinit { countListener?.remove() }
    
    // MARK: - Check if user has RSVP'd
    func checkRSVP(eventId: String, uid: String) async {
        let docRef = db.collection("events").document(eventId).collection("rsvps").document(uid)
        let doc = try? await docRef.getDocument()
        if doc?.exists == true {
            rsvpedEventIds.insert(eventId)
        }
    }
    
    func isRSVPed(eventId: String) -> Bool {
        rsvpedEventIds.contains(eventId)
    }
    
    // MARK: - RSVP (create)
    func rsvp(eventId: String, uid: String, email: String) async {
        isLoading = true
        errorMessage = nil
        let record = RSVPRecord(uid: uid, userEmail: email, eventId: eventId, timestamp: Timestamp(date: Date()))
        do {
            try db.collection("events").document(eventId)
                .collection("rsvps").document(uid).setData(from: record)
            rsvpedEventIds.insert(eventId)
            HapticManager.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
        }
        isLoading = false
    }
    
    // MARK: - Cancel RSVP
    func cancelRSVP(eventId: String, uid: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await db.collection("events").document(eventId)
                .collection("rsvps").document(uid).delete()
            rsvpedEventIds.remove(eventId)
            HapticManager.impact(.light)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
        }
        isLoading = false
    }
    
    // MARK: - Live RSVP count listener
    func listenRSVPCount(eventId: String) {
        countListener?.remove()
        countListener = db.collection("events").document(eventId)
            .collection("rsvps")
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    self?.rsvpCount = snapshot?.count ?? 0
                }
            }
    }
    
    func clearError() { errorMessage = nil }
}
