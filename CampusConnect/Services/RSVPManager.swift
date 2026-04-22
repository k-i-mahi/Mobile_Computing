// ============================================================
// RSVPManager.swift
// RSVP check, toggle, and count via Firestore transactions
// ============================================================

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class RSVPManager: ObservableObject {

    @Published var rsvpedEventIds: Set<String> = []
    @Published var isProcessing: Bool = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // MARK: - Load user RSVPs

    func startListening(uid: String) {
        listener?.remove()
        listener = db.collection("users").document(uid)
            .collection("rsvps")
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.rsvpedEventIds = Set(snapshot?.documents.map { $0.documentID } ?? [])
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        rsvpedEventIds = []
    }

    func isRSVPed(eventId: String) -> Bool {
        rsvpedEventIds.contains(eventId)
    }

    // MARK: - Toggle

    func toggleRSVP(event: Event, uid: String) async throws {
        isProcessing = true
        defer { isProcessing = false }

        let eventRef = db.collection("events").document(event.id)
        let rsvpRef  = db.collection("users").document(uid).collection("rsvps").document(event.id)

        if isRSVPed(eventId: event.id) {
            try await removeRSVP(eventRef: eventRef, rsvpRef: rsvpRef, eventId: event.id)
        } else {
            try await addRSVP(event: event, eventRef: eventRef, rsvpRef: rsvpRef, uid: uid)
        }
        HapticManager.notification(.success)
    }

    // MARK: - RSVP Count

    func fetchRSVPCount(eventId: String) async -> Int {
        let snapshot = try? await db.collection("users")
            .whereField("rsvps.\(eventId)", isEqualTo: true)
            .getDocuments()
        return snapshot?.documents.count ?? 0
    }

    // MARK: - Private

    private func addRSVP(event: Event, eventRef: DocumentReference, rsvpRef: DocumentReference, uid: String) async throws {
        try await db.runTransaction { transaction, errorPointer in
            let eventDoc: DocumentSnapshot
            do {
                eventDoc = try transaction.getDocument(eventRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            let currentCount = eventDoc.data()?["rsvpCount"] as? Int ?? 0
            let maxSeats      = eventDoc.data()?["maxSeats"] as? Int ?? 0

            if maxSeats > 0 && currentCount >= maxSeats {
                errorPointer?.pointee = NSError(
                    domain: "RSVPManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "This event is fully booked."]
                )
                return nil
            }

            transaction.updateData(["rsvpCount": FieldValue.increment(Int64(1))], forDocument: eventRef)
            transaction.setData([
                "eventId": event.id,
                "title": event.title,
                "date": Timestamp(date: event.date),
                "rsvpedAt": Timestamp(date: Date())
            ], forDocument: rsvpRef)
            return nil
        }
    }

    private func removeRSVP(eventRef: DocumentReference, rsvpRef: DocumentReference, eventId: String) async throws {
        try await db.runTransaction { transaction, _ in
            transaction.updateData(["rsvpCount": FieldValue.increment(Int64(-1))], forDocument: eventRef)
            transaction.deleteDocument(rsvpRef)
            return nil
        }
    }
}
