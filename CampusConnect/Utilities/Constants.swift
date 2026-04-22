// ============================================================
// Constants.swift
// App-wide design tokens, colors, and configuration
// ============================================================

import SwiftUI
import Combine

enum Constants {
    
    // MARK: - API Keys
    nonisolated static let cloudinaryCloudName = "dekugln9v"
    nonisolated static let cloudinaryEventsUploadPreset = "campusconnect_events_unsigned"
    nonisolated static let cloudinaryProfilesUploadPreset = "campusconnect_profiles_unsigned"
    nonisolated static let cloudinaryUploadPreset = cloudinaryEventsUploadPreset

    nonisolated static var isCloudinaryConfigured: Bool {
        !cloudinaryCloudName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cloudinaryEventsUploadPreset.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Campus Policy
    static let campusEmailDomain = "stud.kuet.ac.bd"
    static let maxEventsPerDayWithoutFlag = 3
    static let maxCommentsPerEventWithoutFlag = 50
    static let warningBanThreshold = 4
    
    // MARK: - Event Categories
    static let eventCategories = [
        "Academic", "Sports", "Cultural", "Tech", "Workshop", "Social"
    ]

    static let eventSortOptions: [EventSortOption] = [
        .newest,
        .trending,
        .mostUpvoted,
        .mostDiscussed,
        .nearestUpcoming
    ]

    static let reportCategories = [
        "False Information",
        "Abusive Content",
        "Spam",
        "Fake Organizer",
        "Harassment",
        "Other"
    ]
    
    // MARK: - Design Tokens
    enum Design {
        static let cornerRadius: CGFloat      = 18
        static let cardCornerRadius: CGFloat   = 20
        static let smallCornerRadius: CGFloat  = 12
        static let buttonHeight: CGFloat       = 54
        static let cardShadowRadius: CGFloat   = 12
        static let cardShadowOpacity: Double   = 0.08
        static let horizontalPadding: CGFloat  = 20
        static let cardSpacing: CGFloat        = 16
        static let sectionSpacing: CGFloat     = 24
    }
    
    // MARK: - Colors
    enum Colors {
        // Primary brand
        static let brandGradientStart = Color(red: 0.18, green: 0.35, blue: 0.92)
        static let brandGradientEnd   = Color(red: 0.42, green: 0.25, blue: 0.88)
        
        // Semantic
        static let accent  = Color(red: 1.0, green: 0.44, blue: 0.26)
        static let success = Color(red: 0.20, green: 0.78, blue: 0.45)
        static let warning = Color(red: 1.0, green: 0.72, blue: 0.20)
        static let danger  = Color(red: 0.92, green: 0.26, blue: 0.28)
        
        // Surfaces
        static let cardBackground = Color(.secondarySystemGroupedBackground)
        static let pageBackground = Color(.systemGroupedBackground)
        
        // Gradients
        static var brandGradient: LinearGradient {
            LinearGradient(
                colors: [brandGradientStart, brandGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        static var warmGradient: LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.44, blue: 0.26),
                    Color(red: 0.95, green: 0.25, blue: 0.48)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        static var freshGradient: LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.82, blue: 0.60),
                    Color(red: 0.10, green: 0.55, blue: 0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Category Theming
    enum CategoryColors {
        static func color(for category: String) -> Color {
            switch category.lowercased() {
            case "academic":  return Color(red: 0.25, green: 0.47, blue: 0.96)
            case "sports":    return Color(red: 0.20, green: 0.78, blue: 0.45)
            case "cultural":  return Color(red: 0.62, green: 0.32, blue: 0.88)
            case "tech":      return Color(red: 1.0, green: 0.55, blue: 0.18)
            case "workshop":  return Color(red: 0.14, green: 0.72, blue: 0.76)
            case "social":    return Color(red: 0.94, green: 0.32, blue: 0.54)
            default:          return .secondary
            }
        }
        
        static func gradient(for category: String) -> LinearGradient {
            let base = color(for: category)
            return LinearGradient(
                colors: [base, base.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        static func icon(for category: String) -> String {
            switch category.lowercased() {
            case "academic":  return "book.fill"
            case "sports":    return "sportscourt.fill"
            case "cultural":  return "theatermasks.fill"
            case "tech":      return "laptopcomputer"
            case "workshop":  return "wrench.and.screwdriver.fill"
            case "social":    return "person.3.fill"
            default:          return "calendar"
            }
        }
    }
}

enum AppUserRole: String, Codable, CaseIterable {
    case user = "USER"
    case admin = "ADMIN"
}

enum UserRestrictionStatus: String, Codable {
    case active = "ACTIVE"
    case commentRestricted = "COMMENT_RESTRICTED"
    case eventRestricted = "EVENT_RESTRICTED"
    case banned = "BANNED"
}

enum EventLifecycleStatus: String, Codable, CaseIterable {
    case draft = "DRAFT"
    case pendingApproval = "PENDING_APPROVAL"
    case approved = "APPROVED"
    case rejected = "REJECTED"
    case expired = "EXPIRED"
    case archived = "ARCHIVED"
    case removedByAdmin = "REMOVED_BY_ADMIN"

    var userFacingLabel: String {
        switch self {
        case .draft: return "Draft"
        case .pendingApproval: return "Pending Approval"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .expired: return "Expired"
        case .archived: return "Archived"
        case .removedByAdmin: return "Removed by Admin"
        }
    }
}

enum EventSortOption: String, Codable, CaseIterable, Identifiable {
    case newest = "Newest"
    case trending = "Trending"
    case mostUpvoted = "Most Upvoted"
    case mostDiscussed = "Most Discussed"
    case nearestUpcoming = "Nearest Upcoming"

    var id: String { rawValue }
}
