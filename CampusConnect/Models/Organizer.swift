// ============================================================
// Organizer.swift
// Organizer data model
// ============================================================

import Foundation

struct Organizer: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let role: String
    let department: String
    let email: String
    let phone: String?
    let bio: String?
    let imageName: String?
    
    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.compactMap { $0.first }
        return String(letters.prefix(2)).uppercased()
    }
    
    var displayBio: String {
        bio ?? "No bio available."
    }
    
    var hasContactInfo: Bool {
        !email.isEmpty || phone != nil
    }
}
