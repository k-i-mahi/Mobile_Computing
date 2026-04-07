// ============================================================
// AuthViewModel.swift
// Firebase Authentication state management
// ============================================================

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AuthViewModel: ObservableObject {
    
    @Published var user: User?
    @Published var isSignedIn: Bool = false
    @Published var authError: String?
    @Published var isLoading: Bool = false
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    
    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isSignedIn = user != nil
            }
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, displayName: String) async {
        let validation = ValidationService.validateSignUp(email: email, password: password, name: displayName)
        guard validation.isValid else {
            authError = validation.message
            HapticManager.notification(.warning)
            return
        }
        isLoading = true
        authError = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            
            let profile = UserProfile(
                uid: result.user.uid,
                displayName: displayName,
                department: "",
                email: email,
                phone: nil,
                bio: nil,
                joinDate: DateFormatterHelper.string(from: Date())
            )
            try db.collection("users").document(result.user.uid).setData(from: profile)
            HapticManager.notification(.success)
        } catch {
            authError = error.localizedDescription
            HapticManager.notification(.error)
        }
        isLoading = false
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async {
        let validation = ValidationService.validateSignIn(email: email, password: password)
        guard validation.isValid else {
            authError = validation.message
            HapticManager.notification(.warning)
            return
        }
        isLoading = true
        authError = nil
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            HapticManager.notification(.success)
        } catch {
            authError = error.localizedDescription
            HapticManager.notification(.error)
        }
        isLoading = false
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            try Auth.auth().signOut()
            HapticManager.impact(.medium)
        } catch {
            authError = error.localizedDescription
        }
    }
    
    // MARK: - Helpers
    var currentUID: String? { user?.uid }
    var currentEmail: String { user?.email ?? "" }
    var currentDisplayName: String { user?.displayName ?? "Student" }
    
    func clearError() { authError = nil }
}
