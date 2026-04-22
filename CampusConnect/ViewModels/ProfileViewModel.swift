// ============================================================
// ProfileViewModel.swift
// Handles user profile load/save in Firestore
// ============================================================

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    
    @Published var profile: UserProfile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var saveSuccess: Bool = false
    
    private let db = Firestore.firestore()
    
    // MARK: - Load
    func loadProfile(uid: String, email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if doc.exists {
                profile = try doc.data(as: UserProfile.self)
            } else {
                profile = UserProfile.empty(uid: uid, email: email)
            }
        } catch {
            errorMessage = error.localizedDescription
            profile = UserProfile.empty(uid: uid, email: email)
        }
        isLoading = false
    }
    
    // MARK: - Save
    func saveProfile() async {
        guard let profile else { return }
        isLoading = true
        errorMessage = nil
        do {
            try db.collection("users").document(profile.uid).setData(from: profile, merge: true)

            if let currentUser = Auth.auth().currentUser,
               currentUser.uid == profile.uid {
                let change = currentUser.createProfileChangeRequest()
                change.displayName = profile.displayName
                try await change.commitChanges()
            }

            try await syncDisplayNameAcrossApp(uid: profile.uid, displayName: profile.displayName)

            saveSuccess = true
            HapticManager.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
        }
        isLoading = false
    }
    
    func updateField<T>(_ keyPath: WritableKeyPath<UserProfile, T>, value: T) {
        profile?[keyPath: keyPath] = value
    }

    private func syncDisplayNameAcrossApp(uid: String, displayName: String) async throws {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let now = Timestamp(date: Date())
        var batch = db.batch()
        var operations = 0

        func enqueue(_ ref: DocumentReference, _ data: [String: Any]) async throws {
            if operations >= 450 {
                try await batch.commit()
                batch = db.batch()
                operations = 0
            }
            batch.setData(data, forDocument: ref, merge: true)
            operations += 1
        }

        let createdEvents = try await db.collection("events")
            .whereField("creatorUid", isEqualTo: uid)
            .getDocuments()
        for eventDoc in createdEvents.documents {
            try await enqueue(eventDoc.reference, [
                "organizerName": trimmedName,
                "updatedAt": now
            ])
        }

        let authoredComments = try await db.collectionGroup("comments")
            .whereField("authorUid", isEqualTo: uid)
            .getDocuments()
        for commentDoc in authoredComments.documents {
            try await enqueue(commentDoc.reference, [
                "authorName": trimmedName,
                "updatedAt": now
            ])
        }

        let authoredReplies = try await db.collectionGroup("replies")
            .whereField("authorUid", isEqualTo: uid)
            .getDocuments()
        for replyDoc in authoredReplies.documents {
            try await enqueue(replyDoc.reference, [
                "authorName": trimmedName,
                "updatedAt": now
            ])
        }

        if operations > 0 {
            try await batch.commit()
        }
    }
}
