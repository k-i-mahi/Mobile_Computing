// ============================================================
// UserProfile.swift
// User profile data model stored in Firestore /users/{uid}
// ============================================================

import Foundation

struct UserProfile: Codable, Equatable {
    var uid: String
    var displayName: String
    var department: String
    var email: String
    var phone: String?
    var bio: String?
    var joinDate: String?
    
    var initials: String {
        let parts = displayName.split(separator: " ")
        return parts.compactMap { $0.first }.prefix(2).map(String.init).joined().uppercased()
    }
    
    var hasCompletedProfile: Bool {
        !displayName.isEmpty && !department.isEmpty
    }
    
    var displayJoinDate: String {
        if let joinDate, let formatted = DateFormatterHelper.display(from: joinDate) {
            return "Joined \(formatted)"
        }
        return "New member"
    }
    
    static func empty(uid: String, email: String) -> UserProfile {
        UserProfile(
            uid: uid,
            displayName: "",
            department: "",
            email: email,
            phone: nil,
            bio: nil,
            joinDate: DateFormatterHelper.string(from: Date())
        )
    }
}
