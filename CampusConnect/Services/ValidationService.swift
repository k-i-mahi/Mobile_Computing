// ============================================================
// ValidationService.swift
// Form validation with detailed rules
// ============================================================

import Foundation
import Combine

struct ValidationResult {
    let isValid: Bool
    let message: String
    
    static let valid = ValidationResult(isValid: true, message: "")
    static func invalid(_ message: String) -> ValidationResult {
        ValidationResult(isValid: false, message: message)
    }
}

enum ValidationService {

    static func isValidCampusEmail(_ email: String) -> Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasSuffix("@\(Constants.campusEmailDomain)")
    }
    
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
        guard isValidCampusEmail(trimmedEmail) else {
            return .invalid("Use your campus email (@\(Constants.campusEmailDomain)) to continue.")
        }
        
        guard !password.isEmpty else {
            return .invalid("Password cannot be empty")
        }
        guard password.count >= 6 else {
            return .invalid("Password must be at least 6 characters.")
        }
        guard password.range(of: #"[A-Z]"#, options: .regularExpression) != nil,
              password.range(of: #"[a-z]"#, options: .regularExpression) != nil,
              password.range(of: #"[0-9]"#, options: .regularExpression) != nil else {
            return .invalid("Use a stronger password with upper, lower, and number.")
        }
        
        return .valid
    }
    
    static func validateSignIn(email: String, password: String) -> ValidationResult {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .invalid("Please enter your email.")
        }
        guard isValidCampusEmail(email) else {
            return .invalid("Only campus accounts can sign in.")
        }
        guard !password.isEmpty else {
            return .invalid("Password cannot be empty")
        }
        return .valid
    }

    static func validatePasswordReset(newPassword: String, confirmPassword: String) -> ValidationResult {
        guard !newPassword.isEmpty else {
            return .invalid("Password cannot be empty")
        }
        guard newPassword.count >= 6 else {
            return .invalid("Password must be at least 6 characters.")
        }
        guard newPassword.range(of: #"[A-Z]"#, options: .regularExpression) != nil,
              newPassword.range(of: #"[a-z]"#, options: .regularExpression) != nil,
              newPassword.range(of: #"[0-9]"#, options: .regularExpression) != nil else {
            return .invalid("Use a stronger password with upper, lower, and number.")
        }
        guard newPassword == confirmPassword else {
            return .invalid("New password and confirm password do not match.")
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

    static func validateRichEventForm(
        title: String,
        venue: String,
        hostName: String,
        hostEmail: String,
        hostPhone: String,
        organizationName: String,
        description: String,
        registrationLink: String,
        category: String
    ) -> ValidationResult {
        let base = validateEvent(title: title, venue: venue, date: "x", category: category)
        guard base.isValid else { return base }

        guard !hostName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid("Host name is required.")
        }

        let trimmedHostEmail = hostEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHostEmail.isEmpty else {
            return .invalid("Host email is required.")
        }

        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        guard trimmedHostEmail.range(of: emailRegex, options: .regularExpression) != nil else {
            return .invalid("Please provide a valid host email.")
        }

        let trimmedHostPhone = hostPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHostPhone.isEmpty else {
            return .invalid("Host contact number is required.")
        }

        let digitsOnly = trimmedHostPhone.filter { $0.isNumber }
        guard digitsOnly.count >= 7 else {
            return .invalid("Please provide a valid host contact number.")
        }

        guard !organizationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid("Organization or club name is required.")
        }

        guard description.trimmingCharacters(in: .whitespacesAndNewlines).count >= 24 else {
            return .invalid("Event description should be at least 24 characters.")
        }

        if !registrationLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           URL(string: registrationLink) == nil {
            return .invalid("Registration link is invalid.")
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
