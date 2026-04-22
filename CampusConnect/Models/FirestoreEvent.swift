// ============================================================
// FirestoreEvent.swift
// Firestore-backed event model for user-created events
// ============================================================

import Foundation
import FirebaseFirestore

struct FirestoreEvent: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var venue: String
    var date: String
    var category: String
    var creatorUid: String
    var creatorEmail: String
    var createdAt: Timestamp?
    var updatedAt: Timestamp?
    var seats: Int?
    var tags: [String]?
    var organizerName: String?
    var organizerRole: String?
    var hostEmail: String?
    var hostPhone: String?
    var imageName: String?
    var imageURL: String?
    var imagePublicId: String?
    var hostIdentityType: String?
    var organizationName: String?
    var registrationLink: String?
    var socialLinks: [String]?
    var agenda: [String]?
    var speakers: [String]?
    var faqs: [EventFAQ]?
    var status: String?
    var rejectionReason: String?
    var rejectionHistory: [RejectionHistoryItem]?
    var isApproved: Bool?
    var upvoteCount: Int?
    var commentCount: Int?
    var replyCount: Int?
    var uniqueCommenterCount: Int?
    var trendingScore: Double?
    var discussionScore: Double?
    var removedByAdmin: Bool?
    var archivedAt: Timestamp?

    // MARK: – Computed Properties

    /// Formatted display date (e.g. "Jan 15, 2025 at 7:00 PM")
    var formattedDate: String {
        DateFormatterHelper.display(from: date) ?? date
    }

    /// Short date (e.g. "Jan 15, 2025")
    var shortDate: String {
        DateFormatterHelper.shortDisplay(from: date) ?? date
    }

    /// Whether the event is in the future
    var isUpcoming: Bool {
        DateFormatterHelper.isUpcoming(date)
    }

    /// Day and month tuple for calendar cards — always returns a value
    var dayMonth: (day: String, month: String) {
        if let dm = DateFormatterHelper.dayMonth(from: date) {
            return dm
        }
        return ("--", "---")
    }

    /// First letter of the creator's email for avatar display
    var creatorInitial: String {
        String(creatorEmail.prefix(1)).uppercased()
    }

    var lifecycleStatus: EventLifecycleStatus {
        if let parsed = EventLifecycleStatus(rawValue: status ?? "") {
            switch parsed {
            case .approved:
                return isExpiredByDate ? .expired : .approved
            default:
                return parsed
            }
        }

        if isApproved == true {
            return isExpiredByDate ? .expired : .approved
        }

        return EventLifecycleStatus(rawValue: status ?? "") ?? .draft
    }

    private var isExpiredByDate: Bool {
        guard let eventDate = DateFormatterHelper.date(from: date) else { return false }
        let expiresAt = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: eventDate)
        ) ?? eventDate
        return expiresAt <= Date()
    }

    var discussionHighlight: String? {
        let count = uniqueCommenterCount ?? 0
        guard count >= 10 else { return nil }
        if count >= 1000 {
            let value = Double(count) / 1000.0
            return String(format: "%.1fk people are talking about this", value)
        }
        return "\(count) people are talking about this"
    }

    /// Convert to Event model for use with existing views
    var asEvent: Event {
        Event(
            id: id ?? UUID().uuidString,
            title: title,
            description: description,
            venue: venue,
            date: date,
            category: category,
            organizerName: organizerName ?? creatorEmail.components(separatedBy: "@").first ?? "Organizer",
            organizerRole: organizerRole ?? "Event Organizer",
            organizerDepartment: organizationName,
            organizerEmail: hostEmail ?? creatorEmail,
            organizerPhone: hostPhone,
            imageName: imageName,
            seats: seats,
            tags: tags,
            status: lifecycleStatus,
            createdAtUnix: createdAt?.dateValue().timeIntervalSince1970,
            upvoteCount: upvoteCount ?? 0,
            commentCount: commentCount ?? 0,
            replyCount: replyCount ?? 0,
            uniqueCommenterCount: uniqueCommenterCount ?? 0,
            trendingScore: trendingScore ?? 0,
            discussionLabel: discussionHighlight,
            registrationLink: registrationLink,
            agenda: agenda,
            speakers: speakers,
            faqs: faqs,
            socialLinks: socialLinks,
            imageURL: imageURL,
            rejectionReason: rejectionReason,
            creatorUid: creatorUid
        )
    }

    // MARK: – Memberwise Init

    init(
        id: String? = nil,
        title: String,
        description: String,
        venue: String,
        date: String,
        category: String,
        creatorUid: String,
        creatorEmail: String,
        createdAt: Timestamp? = nil,
        updatedAt: Timestamp? = nil,
        seats: Int? = nil,
        tags: [String]? = nil,
        organizerName: String? = nil,
        organizerRole: String? = nil,
        hostEmail: String? = nil,
        hostPhone: String? = nil,
        imageName: String? = nil,
        imageURL: String? = nil,
        imagePublicId: String? = nil,
        hostIdentityType: String? = "PERSONAL",
        organizationName: String? = nil,
        registrationLink: String? = nil,
        socialLinks: [String]? = nil,
        agenda: [String]? = nil,
        speakers: [String]? = nil,
        faqs: [EventFAQ]? = nil,
        status: String = EventLifecycleStatus.pendingApproval.rawValue,
        rejectionReason: String? = nil,
        rejectionHistory: [RejectionHistoryItem]? = nil,
        isApproved: Bool? = false,
        upvoteCount: Int = 0,
        commentCount: Int = 0,
        replyCount: Int = 0,
        uniqueCommenterCount: Int = 0,
        trendingScore: Double = 0,
        discussionScore: Double = 0,
        removedByAdmin: Bool = false,
        archivedAt: Timestamp? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.venue = venue
        self.date = date
        self.category = category
        self.creatorUid = creatorUid
        self.creatorEmail = creatorEmail
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.seats = seats
        self.tags = tags
        self.organizerName = organizerName
        self.organizerRole = organizerRole
        self.hostEmail = hostEmail
        self.hostPhone = hostPhone
        self.imageName = imageName
        self.imageURL = imageURL
        self.imagePublicId = imagePublicId
        self.hostIdentityType = hostIdentityType
        self.organizationName = organizationName
        self.registrationLink = registrationLink
        self.socialLinks = socialLinks
        self.agenda = agenda
        self.speakers = speakers
        self.faqs = faqs
        self.status = status
        self.rejectionReason = rejectionReason
        self.rejectionHistory = rejectionHistory
        self.isApproved = isApproved
        self.upvoteCount = upvoteCount
        self.commentCount = commentCount
        self.replyCount = replyCount
        self.uniqueCommenterCount = uniqueCommenterCount
        self.trendingScore = trendingScore
        self.discussionScore = discussionScore
        self.removedByAdmin = removedByAdmin
        self.archivedAt = archivedAt
    }
}

struct EventFAQ: Codable, Hashable {
    var question: String
    var answer: String
}

struct RejectionHistoryItem: Codable, Hashable {
    var reason: String
    var rejectedByUID: String
    var rejectedAt: Timestamp
}
