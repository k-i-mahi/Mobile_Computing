import Foundation
import FirebaseFirestore

final class ClientNotificationService {
    static let shared = ClientNotificationService()

    private let db = Firestore.firestore()

    private init() {}

    func notifyEventOwnerOfComment(
        eventId: String,
        commentId: String,
        actorUid: String,
        actorName: String
    ) async {
        do {
            let eventSnapshot = try await db.collection("events").document(eventId).getDocument()
            guard let event = eventSnapshot.data() else { return }
            let ownerUid = event["creatorUid"] as? String ?? ""
            guard !ownerUid.isEmpty, ownerUid != actorUid else { return }

            try await writeNotification(
                uid: ownerUid,
                actorUid: actorUid,
                eventId: eventId,
                eventTitle: eventTitle(from: event),
                kind: "NEW_COMMENT_ON_YOUR_EVENT",
                message: "\(actorName) commented on your event.",
                targetCommentId: commentId,
                dedupeKey: "COMMENT_ON_OWN|\(eventId)|\(commentId)"
            )
        } catch {
            // Notification side effects should not block the primary comment action.
        }
    }

    func notifyCommentAuthorOfReply(
        eventId: String,
        commentId: String,
        replyId: String,
        actorUid: String,
        actorName: String
    ) async {
        do {
            let commentSnapshot = try await db.collection("events").document(eventId)
                .collection("comments").document(commentId)
                .getDocument()
            guard let comment = commentSnapshot.data() else { return }
            let ownerUid = comment["authorUid"] as? String ?? ""
            guard !ownerUid.isEmpty, ownerUid != actorUid else { return }

            let eventSnapshot = try? await db.collection("events").document(eventId).getDocument()
            try await writeNotification(
                uid: ownerUid,
                actorUid: actorUid,
                eventId: eventId,
                eventTitle: eventTitle(from: eventSnapshot?.data()),
                kind: "REPLY_TO_YOUR_COMMENT",
                message: "\(actorName) replied to your comment.",
                targetCommentId: commentId,
                targetReplyId: replyId,
                dedupeKey: "REPLY_TO_YOU|\(eventId)|\(commentId)|\(replyId)"
            )
        } catch {
            // Notification side effects should not block the primary reply action.
        }
    }

    func notifyEventOwnerOfUpvote(eventId: String, actorUid: String) async {
        do {
            let eventSnapshot = try await db.collection("events").document(eventId).getDocument()
            guard let event = eventSnapshot.data() else { return }
            let ownerUid = event["creatorUid"] as? String ?? ""
            guard !ownerUid.isEmpty, ownerUid != actorUid else { return }

            try await writeNotification(
                uid: ownerUid,
                actorUid: actorUid,
                eventId: eventId,
                eventTitle: eventTitle(from: event),
                kind: "UPVOTE_ON_YOUR_EVENT",
                message: "Someone upvoted your event.",
                dedupeKey: "UPVOTE_ON_OWN|\(eventId)|\(actorUid)"
            )
        } catch {
            // Notification side effects should not block the primary upvote action.
        }
    }

    func notifyReminderFollowersOfEventChange(
        eventId: String,
        eventTitle: String,
        actorUid: String,
        changedFields: [String],
        venue: String,
        date: String
    ) async {
        guard !changedFields.isEmpty else { return }

        do {
            let eventSnapshot = try await db.collection("events").document(eventId).getDocument()
            let creatorUid = eventSnapshot.data()?["creatorUid"] as? String ?? actorUid

            let snapshot = try await db.collection("event_notification_subscribers")
                .document(eventId)
                .collection("users")
                .whereField("isEnabled", isEqualTo: true)
                .whereField("eventCreatorUid", isEqualTo: creatorUid)
                .getDocuments()

            let message = "Event \(changedFields.joined(separator: " and ")) changed. Please review updated details."
            for doc in snapshot.documents {
                let uid = doc.documentID
                guard uid != actorUid else { continue }

                try await writeNotification(
                    uid: uid,
                    actorUid: actorUid,
                    eventId: eventId,
                    eventTitle: eventTitle,
                    kind: "EVENT_DETAILS_CHANGED",
                    message: message,
                    dedupeKey: "DETAILS|\(eventId)|\(uid)|\(venue)|\(date)"
                )
            }
        } catch {
            // Event updates must still succeed even if follower notification fan-out fails.
        }
    }

    private func writeNotification(
        uid: String,
        actorUid: String,
        eventId: String,
        eventTitle: String,
        kind: String,
        message: String,
        targetCommentId: String? = nil,
        targetReplyId: String? = nil,
        dedupeKey: String
    ) async throws {
        var payload: [String: Any] = [
            "eventId": eventId,
            "eventTitle": eventTitle,
            "kind": kind,
            "message": message,
            "actorUid": actorUid,
            "dedupeKey": dedupeKey,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let targetCommentId {
            payload["targetCommentId"] = targetCommentId
        }
        if let targetReplyId {
            payload["targetReplyId"] = targetReplyId
        }

        try await db.collection("user_notifications").document(uid)
            .collection("items").document(notificationDocId(dedupeKey))
            .setData(payload, merge: false)
    }

    private func eventTitle(from data: [String: Any]?) -> String {
        let title = data?["title"] as? String ?? ""
        return title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Event" : title
    }

    private func notificationDocId(_ dedupeKey: String) -> String {
        let encoded = Data(dedupeKey.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return String(encoded.prefix(120))
    }
}
