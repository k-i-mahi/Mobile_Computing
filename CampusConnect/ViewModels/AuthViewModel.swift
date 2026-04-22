// ============================================================
// AuthViewModel.swift
// Firebase Authentication state management
// ============================================================

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    
    @Published var user: User?
    @Published var isSignedIn: Bool = false
    @Published var authError: String?
    @Published var isLoading: Bool = false
    @Published var role: AppUserRole = .user
    @Published var accountStatus: UserRestrictionStatus = .active
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var profileListener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                self.user = user
                self.isSignedIn = user != nil
                if let user {
                    if !ValidationService.isValidCampusEmail(user.email ?? "") {
                        try? Auth.auth().signOut()
                        self.user = nil
                        self.isSignedIn = false
                        self.role = .user
                        self.accountStatus = .active
                        self.authError = "Only campus accounts can use this app."
                        return
                    }
                    await self.refreshSessionProfile(uid: user.uid)
                    if self.accountStatus == .banned {
                        try? Auth.auth().signOut()
                        self.user = nil
                        self.isSignedIn = false
                        self.authError = "Your account has been permanently banned due to policy violations."
                        return
                    }
                    self.startSessionProfileListener(uid: user.uid)
                } else {
                    self.stopSessionProfileListener()
                    self.role = .user
                    self.accountStatus = .active
                    self.authError = nil
                }
            }
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        profileListener?.remove()
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, displayName: String) async {
        let normalizedEmail = normalizeEmail(email)
        let validation = ValidationService.validateSignUp(email: normalizedEmail, password: password, name: displayName)
        guard validation.isValid else {
            authError = validation.message
            HapticManager.notification(.warning)
            return
        }
        isLoading = true
        authError = nil
        do {
            if await accountExists(email: normalizedEmail) == true {
                authError = "Account is already registered. Please sign in!"
                HapticManager.notification(.warning)
                isLoading = false
                return
            }

            let result = try await Auth.auth().createUser(withEmail: normalizedEmail, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            
            let profile = UserProfile(
                uid: result.user.uid,
                displayName: displayName,
                department: "",
                email: normalizedEmail,
                phone: nil,
                bio: nil,
                joinDate: DateFormatterHelper.string(from: Date()),
                role: AppUserRole.user.rawValue,
                accountStatus: UserRestrictionStatus.active.rawValue,
                warningCount: 0,
                gmailConnected: false,
                photoURL: nil
            )
            try await db.collection("users").document(result.user.uid).setData(profileFirestoreData(profile))
            do {
                try await saveAccountRegistry(uid: result.user.uid, email: normalizedEmail, displayName: displayName)
            } catch {
                if await accountExists(email: normalizedEmail) == true {
                    try? Auth.auth().signOut()
                    authError = "Account is already registered. Please sign in!"
                    HapticManager.notification(.warning)
                    isLoading = false
                    return
                }
                throw error
            }
            authError = "Account created successfully."
            HapticManager.notification(.success)
        } catch {
            authError = mapAuthError(error)
            HapticManager.notification(.error)
        }
        isLoading = false
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async {
        let normalizedEmail = normalizeEmail(email)
        let validation = ValidationService.validateSignIn(email: normalizedEmail, password: password)
        guard validation.isValid else {
            authError = validation.message
            HapticManager.notification(.warning)
            return
        }
        isLoading = true
        authError = nil
        do {
            let credential = try await Auth.auth().signIn(withEmail: normalizedEmail, password: password)
            await refreshSessionProfile(uid: credential.user.uid)
            try? await saveAccountRegistry(
                uid: credential.user.uid,
                email: normalizedEmail,
                displayName: credential.user.displayName ?? currentDisplayName
            )
            if accountStatus == .banned {
                try Auth.auth().signOut()
                authError = "Your account has been permanently banned due to policy violations."
                HapticManager.notification(.error)
                isLoading = false
                return
            }

            HapticManager.notification(.success)
        } catch {
            authError = await mapSignInError(error, email: normalizedEmail)
            HapticManager.notification(.error)
        }
        isLoading = false
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            stopSessionProfileListener()
            try Auth.auth().signOut()
            role = .user
            accountStatus = .active
            authError = nil
            HapticManager.impact(.medium)
        } catch {
            authError = error.localizedDescription
        }
    }

    func preparePasswordReset(email: String) async -> Bool {
        let normalizedEmail = normalizeEmail(email)
        guard ValidationService.isValidCampusEmail(normalizedEmail) else {
            authError = "Enter your campus email to continue."
            HapticManager.notification(.warning)
            return false
        }

        isLoading = true
        authError = nil
        defer { isLoading = false }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: normalizedEmail)
            authError = "Password reset email sent. Check your inbox and follow the link."
            HapticManager.notification(.success)
            return false
        } catch {
            authError = mapAuthError(error)
            HapticManager.notification(.error)
            return false
        }
    }

    func updatePassword(email: String, newPassword: String, confirmPassword: String) async -> Bool {
        let normalizedEmail = normalizeEmail(email)

        let validation = ValidationService.validatePasswordReset(
            newPassword: newPassword,
            confirmPassword: confirmPassword
        )
        guard validation.isValid else {
            authError = validation.message
            HapticManager.notification(.warning)
            return false
        }

        guard ValidationService.isValidCampusEmail(normalizedEmail) else {
            authError = "Enter your campus email to continue."
            HapticManager.notification(.warning)
            return false
        }

        authError = "Use the password reset link sent to your email to set a new password."
        HapticManager.notification(.warning)
        return false
    }
    
    // MARK: - Helpers
    var currentUID: String? { user?.uid }
    var currentEmail: String { user?.email ?? "" }
    var currentDisplayName: String { user?.displayName ?? "Student" }
    
    func clearError() { authError = nil }

    private func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func refreshSessionProfile(uid: String) async {
        do {
            let snapshot = try await db.collection("users").document(uid).getDocument()
            if let data = try? snapshot.data(as: UserProfile.self) {
                role = AppUserRole(rawValue: data.role ?? AppUserRole.user.rawValue) ?? .user
                accountStatus = UserRestrictionStatus(rawValue: data.accountStatus ?? UserRestrictionStatus.active.rawValue) ?? .active
            } else {
                let bootstrap = UserProfile(
                    uid: uid,
                    displayName: user?.displayName ?? "",
                    department: "",
                    email: user?.email ?? "",
                    phone: nil,
                    bio: nil,
                    joinDate: DateFormatterHelper.string(from: Date()),
                    role: AppUserRole.user.rawValue,
                    accountStatus: UserRestrictionStatus.active.rawValue,
                    warningCount: 0,
                    gmailConnected: false,
                    photoURL: nil
                )
                try await db.collection("users").document(uid).setData(profileFirestoreData(bootstrap), merge: true)
                role = .user
                accountStatus = .active
            }
            if let email = user?.email, !email.isEmpty {
                try? await saveAccountRegistry(uid: uid, email: normalizeEmail(email), displayName: user?.displayName ?? "")
            }
        } catch {
            role = .user
            accountStatus = .active
        }
    }

    private func startSessionProfileListener(uid: String) {
        profileListener?.remove()
        profileListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    guard let self else { return }
                    guard self.currentUID == uid else { return }
                    guard let snapshot,
                          let profile = try? snapshot.data(as: UserProfile.self) else { return }

                    self.role = AppUserRole(rawValue: profile.role ?? AppUserRole.user.rawValue) ?? .user
                    self.accountStatus = UserRestrictionStatus(rawValue: profile.accountStatus ?? UserRestrictionStatus.active.rawValue) ?? .active

                    if self.accountStatus == .banned {
                        self.stopSessionProfileListener()
                        try? Auth.auth().signOut()
                        self.user = nil
                        self.isSignedIn = false
                        self.authError = "Your account has been permanently banned due to policy violations."
                    }
                }
            }
    }

    private func stopSessionProfileListener() {
        profileListener?.remove()
        profileListener = nil
    }

    private func mapAuthError(_ error: Error) -> String {
        guard let code = AuthErrorCode(rawValue: (error as NSError).code) else {
            return "Something went wrong. Please try again."
        }

        switch code {
        case .invalidEmail:
            return "Invalid campus email format."
        case .wrongPassword:
            return "Password incorrect"
        case .invalidCredential:
            return "Password incorrect"
        case .userDisabled:
            return "This account has been disabled."
        case .networkError:
            return "Network unavailable. Check your internet and try again."
        case .emailAlreadyInUse:
            return "Account is already registered. Please sign in!"
        case .weakPassword:
            return "Weak password. Use at least 6 characters."
        case .userNotFound:
            return "Account not registered yet. Please sign up!"
        case .tooManyRequests:
            return "Too many attempts. Please wait and try again."
        case .operationNotAllowed:
            return "Permission denied. Contact campus app admin."
        default:
            let description = error.localizedDescription.lowercased()
            if description.contains("no user record") || description.contains("user not found") {
                return "Account not registered yet. Please sign up!"
            }
            return "Authentication failed. Please try again."
        }
    }

    private func mapSignInError(_ error: Error, email: String) async -> String {
        let nsError = error as NSError
        let code = AuthErrorCode(rawValue: nsError.code)

        switch code {
        case .wrongPassword:
            return "Password incorrect"
        case .userNotFound:
            return "Account not registered yet. Please sign up!"
        case .invalidCredential:
            if let exists = await accountExists(email: email) {
                return exists
                    ? "Password incorrect"
                    : "Account not registered yet. Please sign up!"
            }
            return "Password incorrect"
        default:
            return mapAuthError(error)
        }
    }

    private func accountExists(email: String) async -> Bool? {
        do {
            let snapshot = try await db.collection("account_registry").document(email).getDocument()
            if snapshot.exists {
                return true
            }
            return false
        } catch {
            return nil
        }
    }

    private func saveAccountRegistry(uid: String, email: String, displayName: String) async throws {
        try await db.collection("account_registry").document(email).setData([
            "uid": uid,
            "email": email,
            "displayName": displayName,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func profileFirestoreData(_ profile: UserProfile) -> [String: Any] {
        var data: [String: Any] = [
            "uid": profile.uid,
            "displayName": profile.displayName,
            "department": profile.department,
            "email": profile.email,
            "joinDate": profile.joinDate ?? DateFormatterHelper.string(from: Date()),
            "role": profile.role ?? AppUserRole.user.rawValue,
            "accountStatus": profile.accountStatus ?? UserRestrictionStatus.active.rawValue,
            "warningCount": profile.warningCount ?? 0,
            "gmailConnected": profile.gmailConnected ?? false
        ]

        if let phone = profile.phone {
            data["phone"] = phone
        }
        if let bio = profile.bio {
            data["bio"] = bio
        }
        if let photoURL = profile.photoURL {
            data["photoURL"] = photoURL
        }

        return data
    }
}
