// ============================================================
// NotificationsViewModel.swift
// Manages in-app notification feed with real-time Firestore updates
// ============================================================

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class NotificationsViewModel: ObservableObject {

    @Published var notifications: [AppNotification] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    // MARK: - Start / Stop

    func start(uid: String, email: String) {
        guard !uid.isEmpty else { return }
        listener?.remove()
        isLoading = true
        listener = db.collection("users")
            .document(uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.notifications = snapshot?.documents.compactMap {
                        try? $0.data(as: AppNotification.self)
                    } ?? []
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        notifications = []
    }

    // MARK: - Mark Read

    func markRead(_ notification: AppNotification) {
        guard let uid = Auth.auth().currentUser?.uid, let id = notification.id else { return }
        db.collection("users").document(uid)
            .collection("notifications").document(id)
            .updateData(["isRead": true])
    }

    func markAllRead() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let unread = notifications.filter { !$0.isRead }
        let batch = db.batch()
        for n in unread {
            guard let id = n.id else { continue }
            let ref = db.collection("users").document(uid)
                .collection("notifications").document(id)
            batch.updateData(["isRead": true], forDocument: ref)
        }
        Task { try? await batch.commit() }
    }

    func delete(_ notification: AppNotification) {
        guard let uid = Auth.auth().currentUser?.uid, let id = notification.id else { return }
        db.collection("users").document(uid)
            .collection("notifications").document(id)
            .delete()
    }
}

// MARK: - AppNotification Model

struct AppNotification: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var body: String
    var type: String
    var isRead: Bool
    var createdAt: Timestamp
    var relatedEventId: String?

    var typeIcon: String {
        switch type {
        case "rsvp":        return "checkmark.seal.fill"
        case "event_update": return "calendar.badge.exclamationmark"
        case "admin":       return "shield.fill"
        case "reminder":    return "bell.fill"
        default:            return "bell.circle.fill"
        }
    }
}
