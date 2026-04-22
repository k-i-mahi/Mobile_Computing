// ============================================================
// Event.swift
// Local JSON-backed event model
// ============================================================

import Foundation

struct Event: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String?
    let venue: String
    let date: String
    let category: String
    let organizerName: String
    let organizerRole: String
    let organizerDepartment: String?
    let organizerEmail: String?
    let organizerPhone: String?
    let imageName: String?
    let seats: Int?
    let tags: [String]?
    let status: EventLifecycleStatus
    let createdAtUnix: Double?
    let upvoteCount: Int
    let commentCount: Int
    let replyCount: Int
    let uniqueCommenterCount: Int
    let trendingScore: Double
    let discussionLabel: String?
    let registrationLink: String?
    let agenda: [String]?
    let speakers: [String]?
    let faqs: [EventFAQ]?
    let socialLinks: [String]?
    let imageURL: String?
    let rejectionReason: String?
    let creatorUid: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case venue
        case date
        case category
        case organizerName
        case organizerRole
        case organizerDepartment
        case organizerEmail
        case organizerPhone
        case imageName
        case seats
        case tags
        case status
        case createdAtUnix
        case upvoteCount
        case commentCount
        case replyCount
        case uniqueCommenterCount
        case trendingScore
        case discussionLabel
        case registrationLink
        case agenda
        case speakers
        case faqs
        case socialLinks
        case imageURL
        case rejectionReason
        case creatorUid
    }
    
    // MARK: - Computed Properties
    var formattedDate: String {
        DateFormatterHelper.display(from: date) ?? date
    }
    
    var shortDate: String {
        DateFormatterHelper.shortDisplay(from: date) ?? date
    }
    
    var isUpcoming: Bool {
        DateFormatterHelper.isUpcoming(date)
    }
    
    var daysUntil: Int? {
        DateFormatterHelper.daysUntil(date)
    }
    
    var dayMonth: (day: String, month: String)? {
        DateFormatterHelper.dayMonth(from: date)
    }
    
    var relativeDate: String {
        DateFormatterHelper.relativeDisplay(from: date) ?? date
    }
    
    var displayDescription: String {
        description ?? "No description available."
    }

    var isInteractable: Bool {
        status == .approved
    }

    var isTrending: Bool {
        upvoteCount >= 20 || trendingScore >= 25
    }

    var createdAtDate: Date? {
        guard let createdAtUnix else { return nil }
        return Date(timeIntervalSince1970: createdAtUnix)
    }
    
    var seatLabel: String? {
        guard let seats else { return nil }
        return "\(seats) seats"
    }
    
    // Build Organizer from embedded fields
    var organizer: Organizer {
        let fallbackName = organizerName.lowercased().replacingOccurrences(of: " ", with: ".")
        return Organizer(
            name: organizerName,
            role: organizerRole,
            department: organizerDepartment ?? "Campus Events Office",
            email: organizerEmail ?? "\(fallbackName)@campus.edu",
            phone: organizerPhone,
            bio: "Dedicated to creating memorable campus experiences.",
            imageName: nil
        )
    }

    init(
        id: String,
        title: String,
        description: String?,
        venue: String,
        date: String,
        category: String,
        organizerName: String,
        organizerRole: String,
        organizerDepartment: String? = nil,
        organizerEmail: String? = nil,
        organizerPhone: String? = nil,
        imageName: String?,
        seats: Int?,
        tags: [String]?,
        status: EventLifecycleStatus = .approved,
        createdAtUnix: Double? = nil,
        upvoteCount: Int = 0,
        commentCount: Int = 0,
        replyCount: Int = 0,
        uniqueCommenterCount: Int = 0,
        trendingScore: Double = 0,
        discussionLabel: String? = nil,
        registrationLink: String? = nil,
        agenda: [String]? = nil,
        speakers: [String]? = nil,
        faqs: [EventFAQ]? = nil,
        socialLinks: [String]? = nil,
        imageURL: String? = nil,
        rejectionReason: String? = nil,
        creatorUid: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.venue = venue
        self.date = date
        self.category = category
        self.organizerName = organizerName
        self.organizerRole = organizerRole
        self.organizerDepartment = organizerDepartment
        self.organizerEmail = organizerEmail
        self.organizerPhone = organizerPhone
        self.imageName = imageName
        self.seats = seats
        self.tags = tags
        self.status = status
        self.createdAtUnix = createdAtUnix
        self.upvoteCount = upvoteCount
        self.commentCount = commentCount
        self.replyCount = replyCount
        self.uniqueCommenterCount = uniqueCommenterCount
        self.trendingScore = trendingScore
        self.discussionLabel = discussionLabel
        self.registrationLink = registrationLink
        self.agenda = agenda
        self.speakers = speakers
        self.faqs = faqs
        self.socialLinks = socialLinks
        self.imageURL = imageURL
        self.rejectionReason = rejectionReason
        self.creatorUid = creatorUid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        venue = try container.decode(String.self, forKey: .venue)
        date = try container.decode(String.self, forKey: .date)
        category = try container.decode(String.self, forKey: .category)
        organizerName = try container.decode(String.self, forKey: .organizerName)
        organizerRole = try container.decode(String.self, forKey: .organizerRole)
        organizerDepartment = try container.decodeIfPresent(String.self, forKey: .organizerDepartment)
        organizerEmail = try container.decodeIfPresent(String.self, forKey: .organizerEmail)
        organizerPhone = try container.decodeIfPresent(String.self, forKey: .organizerPhone)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        seats = try container.decodeIfPresent(Int.self, forKey: .seats)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        status = try container.decodeIfPresent(EventLifecycleStatus.self, forKey: .status) ?? .approved
        createdAtUnix = try container.decodeIfPresent(Double.self, forKey: .createdAtUnix)
        upvoteCount = try container.decodeIfPresent(Int.self, forKey: .upvoteCount) ?? 0
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount) ?? 0
        uniqueCommenterCount = try container.decodeIfPresent(Int.self, forKey: .uniqueCommenterCount) ?? 0
        trendingScore = try container.decodeIfPresent(Double.self, forKey: .trendingScore) ?? 0
        discussionLabel = try container.decodeIfPresent(String.self, forKey: .discussionLabel)
        registrationLink = try container.decodeIfPresent(String.self, forKey: .registrationLink)
        agenda = try container.decodeIfPresent([String].self, forKey: .agenda)
        speakers = try container.decodeIfPresent([String].self, forKey: .speakers)
        faqs = try container.decodeIfPresent([EventFAQ].self, forKey: .faqs)
        socialLinks = try container.decodeIfPresent([String].self, forKey: .socialLinks)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        rejectionReason = try container.decodeIfPresent(String.self, forKey: .rejectionReason)
        creatorUid = try container.decodeIfPresent(String.self, forKey: .creatorUid)
    }
}
