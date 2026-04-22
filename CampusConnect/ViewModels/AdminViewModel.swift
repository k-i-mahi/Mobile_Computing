// ============================================================
// AdminViewModel.swift
// Admin moderation: manage users, events, and send notifications
// ============================================================

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class AdminViewModel: ObservableObject {

    @Published var users: [UserProfile] = []
    @Published var pendingEvents: [FirestoreEvent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let db = Firestore.firestore()

    // MARK: - Load

    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await db.collection("users")
                .order(by: "displayName")
                .limit(to: 100)
                .getDocuments()
            users = snapshot.documents.compactMap { try? $0.data(as: UserProfile.self) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadPendingEvents() async {
        do {
            let snapshot = try await db.collection("events")
                .whereField("status", isEqualTo: "pending")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            pendingEvents = snapshot.documents.compactMap { try? $0.data(as: FirestoreEvent.self) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - User Moderation

    func updateUserStatus(uid: String, status: UserRestrictionStatus) async {
        do {
            try await db.collection("users").document(uid).updateData([
                "accountStatus": status.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            HapticManager.notification(.success)
            successMessage = "User status updated to \(status.rawValue)."
            await loadUsers()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
        }
    }

    func promoteToAdmin(uid: String) async {
        do {
            try await db.collection("users").document(uid).updateData([
                "role": AppUserRole.admin.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            HapticManager.notification(.success)
            successMessage = "User promoted to admin."
            await loadUsers()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
        }
    }

    func warnUser(uid: String) async {
        do {
            try await db.collection("users").document(uid).updateData([
                "warningCount": FieldValue.increment(Int64(1)),
                "updatedAt": FieldValue.serverTimestamp()
            ])
            HapticManager.notification(.success)
            successMessage = "Warning issued."
            await loadUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Event Moderation

    func approveEvent(eventId: String) async {
        do {
            try await db.collection("events").document(eventId).updateData([
                "status": "approved",
                "reviewedAt": FieldValue.serverTimestamp()
            ])
            HapticManager.notification(.success)
            successMessage = "Event approved."
            await loadPendingEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectEvent(eventId: String, reason: String) async {
        do {
            try await db.collection("events").document(eventId).updateData([
                "status": "rejected",
                "rejectionReason": reason,
                "reviewedAt": FieldValue.serverTimestamp()
            ])
            HapticManager.notification(.success)
            successMessage = "Event rejected."
            await loadPendingEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Broadcast Notification

    func sendBroadcastNotification(title: String, body: String, type: String = "admin") async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty,
              !body.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Title and body are required."
            return
        }
        isLoading = true
        do {
            let snapshot = try await db.collection("users").getDocuments()
            let batch = db.batch()
            let now = Timestamp(date: Date())
            for userDoc in snapshot.documents {
                let notifRef = db.collection("users")
                    .document(userDoc.documentID)
                    .collection("notifications")
                    .document()
                batch.setData([
                    "title": title,
                    "body": body,
                    "type": type,
                    "isRead": false,
                    "createdAt": now
                ], forDocument: notifRef)
            }
            try await batch.commit()
            HapticManager.notification(.success)
            successMessage = "Notification sent to \(snapshot.documents.count) users."
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
        }
        isLoading = false
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
