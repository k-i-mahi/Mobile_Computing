import Foundation
import FirebaseFirestore

struct EventComment: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var authorUid: String
    var authorName: String
    var text: String
    var createdAt: Timestamp
    var updatedAt: Timestamp?
    var status: String?
    var replyCount: Int?

    var isRemoved: Bool {
        status == "REMOVED" || status == "REMOVED_BY_ADMIN"
    }

    var displayText: String {
        isRemoved ? "This comment was removed by moderation." : text
    }
}

struct EventReply: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var authorUid: String
    var authorName: String
    var text: String
    var createdAt: Timestamp
    var updatedAt: Timestamp?
    var status: String?

    var isRemoved: Bool {
        status == "REMOVED" || status == "REMOVED_BY_ADMIN"
    }

    var displayText: String {
        isRemoved ? "This reply was removed by moderation." : text
    }
}

struct NoticeBoardItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var title: String
    var sourceType: String
    var sourceName: String?
    var sender: String?
    var originalUrl: String
    var syncedAt: Timestamp?
    var publishedAt: Timestamp?

    var isOfficialKUETNotice: Bool {
        let lowerURL = originalUrl.lowercased()
        return sourceType.uppercased().hasPrefix("KUET_") ||
            sourceName?.lowercased().contains("kuet.ac.bd") == true ||
            lowerURL.contains("kuet.ac.bd") ||
            lowerURL.contains("drive.google.com")
    }

    var sourceTypeText: String {
        switch sourceType.uppercased() {
        case "KUET_LATEST_INFO":
            return "Latest Info"
        case "KUET_ACADEMIC_NOTICE":
            return "Academic Notice"
        case "KUET_ADMINISTRATIVE_NOTICE":
            return "Administrative Notice"
        case "KUET_NOTICE":
            return "Notice"
        default:
            return sourceType
                .replacingOccurrences(of: "KUET_", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    var originalLinkText: String {
        guard let url = URL(string: originalUrl) else { return originalUrl }
        let host = url.host ?? "Official source"
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.isEmpty ? host : "\(host)/\(path)"
    }

    var senderText: String {
        let value = (sender ?? sourceName ?? "Campus Gmail").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Campus Gmail" : value
    }

    var publishedDateText: String {
        let date = publishedAt?.dateValue() ?? syncedAt?.dateValue() ?? Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct UserEventReminder: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var eventId: String
    var eventTitle: String
    var reminderOffsetHours: Int
    var isEnabled: Bool
    var systemPermissionGranted: Bool?
    var eventDate: Timestamp?
    var watchStartedAt: Timestamp?
    var lastSeenUpvoteCount: Int?
    var lastSeenCommentCount: Int?
    var lastSeenReplyCount: Int?
    var lastSeenStatus: String?
    var lastSeenVenue: String?
    var lastSeenDate: String?
    var lastSeenUpvoteObservedAt: Timestamp?
    var nextReminderAt: Timestamp?
    var createdAt: Timestamp?
    var updatedAt: Timestamp?

    var nextReminderText: String {
        guard let date = nextReminderAt?.dateValue() else { return "Not scheduled" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var isEventExpired: Bool {
        guard let date = eventDate?.dateValue() else { return false }
        let expiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date
        return expiresAt <= Date()
    }

    var statusText: String {
        if isEventExpired {
            return "Expired"
        }
        if isEnabled {
            return systemPermissionGranted == false ? "On in app, iOS alerts off" : "On"
        }
        return "Off"
    }
}

struct UserEventNotification: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var eventId: String
    var eventTitle: String
    var kind: String
    var message: String
    var targetCommentId: String?
    var targetReplyId: String?
    var createdAt: Timestamp?

    var createdDate: Date {
        createdAt?.dateValue() ?? Date()
    }

    var iconName: String {
        switch kind {
        case "INTEREST_SPIKE":
            return "flame.fill"
        case "NEW_DISCUSSION":
            return "bubble.left.and.bubble.right.fill"
        case "REPLY_TO_YOUR_COMMENT":
            return "arrowshape.turn.up.left.fill"
        case "NEW_COMMENT_ON_YOUR_EVENT":
            return "text.bubble.fill"
        case "UPVOTE_ON_YOUR_EVENT":
            return "hand.thumbsup.fill"
        case "EVENT_DETAILS_CHANGED":
            return "calendar.badge.clock"
        case "STATUS_CHANGE":
            return "checkmark.seal.fill"
        case "FOLLOW_STARTED":
            return "bell.fill"
        default:
            return "bell.badge.fill"
        }
    }

    var tintColor: String {
        switch kind {
        case "INTEREST_SPIKE":
            return "warning"
        case "NEW_DISCUSSION":
            return "accent"
        case "REPLY_TO_YOUR_COMMENT":
            return "accent"
        case "NEW_COMMENT_ON_YOUR_EVENT":
            return "warning"
        case "UPVOTE_ON_YOUR_EVENT":
            return "warning"
        case "EVENT_DETAILS_CHANGED":
            return "danger"
        case "STATUS_CHANGE":
            return "success"
        default:
            return "brand"
        }
    }
}
