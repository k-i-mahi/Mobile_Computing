// ============================================================
// ValidationService.swift
// Form validation with detailed rules
// ============================================================

import Foundation

struct ValidationResult {
    let isValid: Bool
    let message: String
    
    static let valid = ValidationResult(isValid: true, message: "")
    static func invalid(_ message: String) -> ValidationResult {
        ValidationResult(isValid: false, message: message)
    }
}

enum ValidationService {
    
    static func validateSignUp(email: String, password: String, name: String) -> ValidationResult {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return .invalid("Please enter your full name.")
        }
        guard trimmedName.count >= 2 else {
            return .invalid("Name must be at least 2 characters.")
        }
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else {
            return .invalid("Please enter your email address.")
        }
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        guard trimmedEmail.range(of: emailRegex, options: .regularExpression) != nil else {
            return .invalid("Please enter a valid email address.")
        }
        
        guard password.count >= 6 else {
            return .invalid("Password must be at least 6 characters.")
        }
        
        return .valid
    }
    
    static func validateSignIn(email: String, password: String) -> ValidationResult {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .invalid("Please enter your email.")
        }
        guard !password.isEmpty else {
            return .invalid("Please enter your password.")
        }
        return .valid
    }
    
    static func validateEvent(title: String, venue: String, date: String, category: String) -> ValidationResult {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .invalid("Event title is required.")
        }
        guard title.count <= 100 else {
            return .invalid("Title must be under 100 characters.")
        }
        guard !venue.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .invalid("Venue is required.")
        }
        guard !date.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .invalid("Please select a date.")
        }
        guard !category.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .invalid("Please select a category.")
        }
        return .valid
    }
    
    static func validateProfile(name: String, department: String) -> ValidationResult {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .invalid("Display name cannot be empty.")
        }
        return .valid
    }
}
