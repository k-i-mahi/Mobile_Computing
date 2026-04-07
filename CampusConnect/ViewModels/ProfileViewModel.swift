// ============================================================
// ProfileViewModel.swift
// Handles user profile load/save in Firestore
// ============================================================

import Foundation
import FirebaseFirestore

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
}
