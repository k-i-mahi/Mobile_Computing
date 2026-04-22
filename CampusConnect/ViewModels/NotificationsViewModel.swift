import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var reminders: [UserEventReminder] = []
    @Published var activityItems: [UserEventNotification] = []
    @Published var mailItems: [NoticeBoardItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var permissionDenied = false

    private let db = Firestore.firestore()
    private var remindersListener: ListenerRegistration?
    private var notificationsListener: ListenerRegistration?
    private var mailListener: ListenerRegistration?
    private var ownCommentsListener: ListenerRegistration?
    private var ownEventsListener: ListenerRegistration?
    private var eventWatchers: [String: ListenerRegistration] = [:]
    private var commentWatchers: [String: ListenerRegistration] = [:]
    private var replyWatchers: [String: ListenerRegistration] = [:]
    private var ownEventCommentWatchers: [String: ListenerRegistration] = [:]
    private var ownEventUpvoteWatchers: [String: ListenerRegistration] = [:]
    private var ownEventWatchStartedAt: [String: Date] = [:]
    private var activeUID: String?
    private var reminderLookup: [String: UserEventReminder] = [:]
    private var lastMailSyncRequestedAt: Date?

    deinit {
        remindersListener?.remove()
        notificationsListener?.remove()
        mailListener?.remove()
        ownCommentsListener?.remove()
        ownEventsListener?.remove()
        eventWatchers.values.forEach { $0.remove() }
        commentWatchers.values.forEach { $0.remove() }
        replyWatchers.values.forEach { $0.remove() }
        ownEventCommentWatchers.values.forEach { $0.remove() }
        ownEventUpvoteWatchers.values.forEach { $0.remove() }
    }

    func start(uid: String, email: String) {
        stop()
        activeUID = uid
        isLoading = true
        errorMessage = nil

        remindersListener = db.collection("user_event_reminders").document(uid)
            .collection("items")
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    guard self.activeUID == uid else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    let fetched = snapshot?.documents.compactMap { try? $0.data(as: UserEventReminder.self) } ?? []
                    self.reminders = fetched
                    self.reminderLookup = Dictionary(uniqueKeysWithValues: fetched.map { ($0.eventId, $0) })
                    self.syncEventWatchers(uid: uid)
                }
            }

        notificationsListener = db.collection("user_notifications").document(uid)
            .collection("items")
            .order(by: "createdAt", descending: true)
            .limit(to: 120)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    guard self.activeUID == uid else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.activityItems = snapshot?.documents.compactMap { try? $0.data(as: UserEventNotification.self) } ?? []
                }
            }

        mailListener = db.collection("synced_gmail_notice_items").document(uid)
            .collection("items")
            .order(by: "syncedAt", descending: true)
            .limit(to: 40)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    guard self.activeUID == uid else { return }
                    if let error {
                        self.errorMessage = "Some optional Gmail notifications are unavailable right now."
                        print(error.localizedDescription)
                        return
                    }
                    self.mailItems = snapshot?.documents.compactMap { try? $0.data(as: NoticeBoardItem.self) } ?? []
                }
            }

        Task {
            await requestGmailSyncIfConnected(uid: uid, email: email)
        }

        startOwnCommentReplyFallback(uid: uid)
        startOwnEventFallback(uid: uid)
    }

    func stop() {
        remindersListener?.remove()
        notificationsListener?.remove()
        mailListener?.remove()
        ownCommentsListener?.remove()
        ownEventsListener?.remove()
        remindersListener = nil
        notificationsListener = nil
        mailListener = nil
        ownCommentsListener = nil
        ownEventsListener = nil
        eventWatchers.values.forEach { $0.remove() }
        commentWatchers.values.forEach { $0.remove() }
        replyWatchers.values.forEach { $0.remove() }
        ownEventCommentWatchers.values.forEach { $0.remove() }
        ownEventUpvoteWatchers.values.forEach { $0.remove() }
        eventWatchers = [:]
        commentWatchers = [:]
        replyWatchers = [:]
        ownEventCommentWatchers = [:]
        ownEventUpvoteWatchers = [:]
        ownEventWatchStartedAt = [:]
        reminderLookup = [:]
        activeUID = nil
        lastMailSyncRequestedAt = nil
        reminders = []
        activityItems = []
        mailItems = []
        isLoading = false
    }

    @discardableResult
    func setReminder(
        uid: String,
        eventId: String,
        eventTitle: String,
        eventDate: Date,
        enabled: Bool,
        offsetHours: Int
    ) async -> Bool {
        if enabled {
            let expiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: eventDate)) ?? eventDate
            guard expiresAt > Date() else {
                errorMessage = "This event has expired."
                return false
            }
        }

        let permission = enabled ? await LocalNotificationService.shared.requestPermissionIfNeeded() : false
        if enabled && !permission {
            permissionDenied = true
        } else if !enabled {
            permissionDenied = false
        }

        let triggerDate = Calendar.current.date(byAdding: .hour, value: -offsetHours, to: eventDate)
        let scheduledReminderAt: Date?
        if enabled, permission, let triggerDate, triggerDate > Date() {
            scheduledReminderAt = triggerDate
        } else {
            scheduledReminderAt = nil
        }

        if enabled, permission, let scheduledReminderAt {
            await LocalNotificationService.shared.scheduleReminder(eventId: eventId, title: eventTitle, triggerDate: scheduledReminderAt)
        } else {
            LocalNotificationService.shared.cancelReminder(eventId: eventId)
        }

        do {
            let docRef = db.collection("user_event_reminders").document(uid)
                .collection("items").document(eventId)
            let existingSnapshot = try? await docRef.getDocument()
            let eventSnapshot = try? await db.collection("events").document(eventId).getDocument()
            let eventCreatorUid = eventSnapshot?.data()?["creatorUid"] as? String
            var payload: [String: Any] = [
                "eventId": eventId,
                "eventTitle": eventTitle,
                "eventDate": Timestamp(date: eventDate),
                "reminderOffsetHours": offsetHours,
                "isEnabled": enabled,
                "systemPermissionGranted": permission,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if let eventCreatorUid {
                payload["eventCreatorUid"] = eventCreatorUid
            }
            if existingSnapshot?.exists != true {
                payload["createdAt"] = FieldValue.serverTimestamp()
            }
            if enabled {
                payload["watchStartedAt"] = Timestamp(date: Date())
                payload["lastSeenUpvoteCount"] = FieldValue.delete()
                payload["lastSeenCommentCount"] = FieldValue.delete()
                payload["lastSeenReplyCount"] = FieldValue.delete()
                payload["lastSeenStatus"] = FieldValue.delete()
                payload["lastSeenVenue"] = FieldValue.delete()
                payload["lastSeenDate"] = FieldValue.delete()
                payload["lastSeenUpvoteObservedAt"] = FieldValue.delete()
                payload["disabledAt"] = FieldValue.delete()
            } else {
                payload["disabledAt"] = FieldValue.serverTimestamp()
            }
            if let scheduledReminderAt {
                payload["nextReminderAt"] = Timestamp(date: scheduledReminderAt)
            } else {
                payload["nextReminderAt"] = FieldValue.delete()
            }
            try await docRef.setData(payload, merge: true)

            let subscriberRef = db.collection("event_notification_subscribers")
                .document(eventId)
                .collection("users")
                .document(uid)
            var subscriberPayload: [String: Any] = [
                "uid": uid,
                "eventId": eventId,
                "eventTitle": eventTitle,
                "isEnabled": enabled,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if let eventCreatorUid {
                subscriberPayload["eventCreatorUid"] = eventCreatorUid
            }
            if enabled {
                if existingSnapshot?.exists != true {
                    subscriberPayload["createdAt"] = FieldValue.serverTimestamp()
                }
                try await subscriberRef.setData(subscriberPayload, merge: true)
            } else {
                subscriberPayload["disabledAt"] = FieldValue.serverTimestamp()
                try await subscriberRef.setData(subscriberPayload, merge: true)
            }

            if enabled {
                try await db.collection("user_notifications").document(uid)
                    .collection("items")
                    .addDocument(data: [
                        "eventId": eventId,
                        "eventTitle": eventTitle,
                        "kind": "FOLLOW_STARTED",
                        "message": permission
                            ? "You will now receive updates for this event."
                            : "Updates are on in CampusConnect. Enable iOS notifications to get device alerts.",
                        "createdAt": FieldValue.serverTimestamp()
                    ])
            }
            return true
        } catch {
            errorMessage = "Failed to update reminder."
            return false
        }
    }

    private func requestGmailSyncIfConnected(uid: String, email: String) async {
        guard activeUID == uid else { return }
        if let lastMailSyncRequestedAt,
           Date().timeIntervalSince(lastMailSyncRequestedAt) < 10 * 60 {
            return
        }
        lastMailSyncRequestedAt = Date()

        do {
            let settings = try await db.collection("gmail_connection_settings").document(uid).getDocument()
            guard settings.data()?["connected"] as? Bool == true else { return }
            _ = try await CampusGmailService.shared.syncIfPossible(uid: uid, campusEmail: email)
        } catch {
            // Optional integration: previously synced mail remains visible if live sync is unavailable.
        }
    }

    private func syncEventWatchers(uid: String) {
        let enabledEventIDs = Set(reminders.filter(\.isEnabled).map(\.eventId))

        let staleIDs = Set(eventWatchers.keys).subtracting(enabledEventIDs)
        for eventId in staleIDs {
            eventWatchers[eventId]?.remove()
            eventWatchers[eventId] = nil
        }

        let staleCommentIDs = Set(commentWatchers.keys).subtracting(enabledEventIDs)
        for eventId in staleCommentIDs {
            commentWatchers[eventId]?.remove()
            commentWatchers[eventId] = nil

            let prefix = "\(eventId)|"
            for key in Array(replyWatchers.keys) where key.hasPrefix(prefix) {
                replyWatchers[key]?.remove()
                replyWatchers[key] = nil
            }
        }

        for eventId in enabledEventIDs where eventWatchers[eventId] == nil {
            eventWatchers[eventId] = db.collection("events").document(eventId)
                .addSnapshotListener { [weak self] snapshot, _ in
                    guard let self else { return }
                    Task { @MainActor in
                        guard self.activeUID == uid else { return }
                        guard let data = snapshot?.data() else { return }
                        await self.processEventUpdate(uid: uid, eventId: eventId, data: data)
                    }
                }
        }

        for eventId in enabledEventIDs where commentWatchers[eventId] == nil {
            commentWatchers[eventId] = db.collection("events").document(eventId)
                .collection("comments")
                .order(by: "createdAt", descending: true)
                .limit(to: 120)
                .addSnapshotListener { [weak self] snapshot, _ in
                    guard let self else { return }
                    Task { @MainActor in
                        guard self.activeUID == uid else { return }
                        guard let reminder = self.reminderLookup[eventId], reminder.isEnabled else { return }
                        let watchStartedAt = reminder.watchStartedAt?.dateValue() ?? Date()

                        for change in snapshot?.documentChanges ?? [] {
                            guard change.type == .added,
                                  let comment = try? change.document.data(as: EventComment.self),
                                  let commentId = comment.id else { continue }

                            if comment.authorUid != uid,
                               comment.createdAt.dateValue() > watchStartedAt {
                                await self.notifyIfCommentOnOwnEvent(uid: uid, eventId: eventId, comment: comment)
                            }

                            if comment.authorUid == uid {
                                self.ensureReplyWatcher(
                                    uid: uid,
                                    eventId: eventId,
                                    commentId: commentId,
                                    watchStartedAt: watchStartedAt
                                )
                            }
                        }

                        let allComments = snapshot?.documents.compactMap { try? $0.data(as: EventComment.self) } ?? []
                        for ownComment in allComments where ownComment.authorUid == uid {
                            guard let ownCommentId = ownComment.id else { continue }
                            self.ensureReplyWatcher(
                                uid: uid,
                                eventId: eventId,
                                commentId: ownCommentId,
                                watchStartedAt: watchStartedAt
                            )
                        }
                    }
                }
        }
    }

    private func startOwnCommentReplyFallback(uid: String) {
        ownCommentsListener?.remove()
        ownCommentsListener = db.collectionGroup("comments")
            .whereField("authorUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    guard self.activeUID == uid else { return }

                    for document in snapshot?.documents ?? [] {
                        guard let eventId = document.reference.parent.parent?.documentID else { continue }
                        self.ensureReplyWatcher(
                            uid: uid,
                            eventId: eventId,
                            commentId: document.documentID,
                            watchStartedAt: Date()
                        )
                    }
                }
            }
    }

    private func startOwnEventFallback(uid: String) {
        ownEventsListener?.remove()
        ownEventsListener = db.collection("events")
            .whereField("creatorUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    guard self.activeUID == uid else { return }

                    let eventIDs = Set(snapshot?.documents.map(\.documentID) ?? [])
                    for stale in Set(self.ownEventCommentWatchers.keys).subtracting(eventIDs) {
                        self.ownEventCommentWatchers[stale]?.remove()
                        self.ownEventCommentWatchers[stale] = nil
                        self.ownEventUpvoteWatchers[stale]?.remove()
                        self.ownEventUpvoteWatchers[stale] = nil
                        self.ownEventWatchStartedAt[stale] = nil
                    }

                    for document in snapshot?.documents ?? [] {
                        self.ensureOwnEventWatchers(uid: uid, eventId: document.documentID, data: document.data())
                    }
                }
            }
    }

    private func ensureOwnEventWatchers(uid: String, eventId: String, data: [String: Any]) {
        let watchStartedAt = ownEventWatchStartedAt[eventId] ?? Date()
        ownEventWatchStartedAt[eventId] = watchStartedAt
        let eventTitle = data["title"] as? String ?? "Your event"

        if ownEventCommentWatchers[eventId] == nil {
            ownEventCommentWatchers[eventId] = db.collection("events").document(eventId)
                .collection("comments")
                .order(by: "createdAt", descending: true)
                .limit(to: 120)
                .addSnapshotListener { [weak self] snapshot, _ in
                    guard let self else { return }
                    Task { @MainActor in
                        guard self.activeUID == uid else { return }

                        for change in snapshot?.documentChanges ?? [] {
                            guard change.type == .added,
                                  let comment = try? change.document.data(as: EventComment.self),
                                  comment.authorUid != uid,
                                  comment.createdAt.dateValue() > watchStartedAt else { continue }

                            await self.pushNotification(
                                uid: uid,
                                eventId: eventId,
                                eventTitle: eventTitle,
                                kind: "NEW_COMMENT_ON_YOUR_EVENT",
                                message: "\(comment.authorName) commented on your event.",
                                targetCommentId: change.document.documentID,
                                dedupeKey: "COMMENT_ON_OWN|\(eventId)|\(change.document.documentID)"
                            )
                        }
                    }
                }
        }

        if ownEventUpvoteWatchers[eventId] == nil {
            ownEventUpvoteWatchers[eventId] = db.collection("events").document(eventId)
                .collection("upvotes")
                .addSnapshotListener { [weak self] snapshot, _ in
                    guard let self else { return }
                    Task { @MainActor in
                        guard self.activeUID == uid else { return }

                        for change in snapshot?.documentChanges ?? [] {
                            guard change.type == .added else { continue }
                            let data = change.document.data()
                            let actorUid = data["uid"] as? String ?? change.document.documentID
                            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                            guard actorUid != uid, createdAt > watchStartedAt else { continue }

                            await self.pushNotification(
                                uid: uid,
                                eventId: eventId,
                                eventTitle: eventTitle,
                                kind: "UPVOTE_ON_YOUR_EVENT",
                                message: "Someone upvoted your event.",
                                dedupeKey: "UPVOTE_ON_OWN|\(eventId)|\(actorUid)"
                            )
                        }
                    }
                }
        }
    }

    private func processEventUpdate(uid: String, eventId: String, data: [String: Any]) async {
        guard let reminder = reminderLookup[eventId], reminder.isEnabled else { return }

        let upvotes = data["upvoteCount"] as? Int ?? 0
        let comments = data["commentCount"] as? Int ?? 0
        let replies = data["replyCount"] as? Int ?? 0
        let status = data["status"] as? String ?? "APPROVED"
        let venue = data["venue"] as? String ?? ""
        let date = data["date"] as? String ?? ""
        let creatorUid = data["creatorUid"] as? String

        let previousUpvotes = reminder.lastSeenUpvoteCount
        let previousComments = reminder.lastSeenCommentCount
        let previousReplies = reminder.lastSeenReplyCount
        let previousStatus = reminder.lastSeenStatus
        let previousVenue = reminder.lastSeenVenue
        let previousDate = reminder.lastSeenDate
        let previousObservedAt = reminder.lastSeenUpvoteObservedAt?.dateValue()

        if previousUpvotes == nil || previousComments == nil || previousReplies == nil || previousStatus == nil {
            await updateWatchState(
                uid: uid,
                eventId: eventId,
                upvotes: upvotes,
                comments: comments,
                replies: replies,
                status: status,
                venue: venue,
                date: date
            )
            return
        }

        let now = Date()
        if creatorUid == uid,
           upvotes > (previousUpvotes ?? 0),
           let previousObservedAt,
           now.timeIntervalSince(previousObservedAt) <= 60 {
            let increase = upvotes - (previousUpvotes ?? 0)
            if increase > 10 {
                await pushNotification(
                    uid: uid,
                    eventId: eventId,
                    eventTitle: reminder.eventTitle,
                    kind: "INTEREST_SPIKE",
                    message: "Upvote surge: +\(increase) people reacted in under 1 minute on your event.",
                    dedupeKey: "SPIKE|\(eventId)|\(upvotes)"
                )
            }
        }

        let previousDiscussion = (previousComments ?? 0) + (previousReplies ?? 0)
        let currentDiscussion = comments + replies
        if currentDiscussion > previousDiscussion {
            await pushNotification(
                uid: uid,
                eventId: eventId,
                eventTitle: reminder.eventTitle,
                kind: "NEW_DISCUSSION",
                message: "New discussion activity on this event.",
                dedupeKey: "DISCUSSION|\(eventId)|\(currentDiscussion)"
            )
        }

        if let previousVenue,
           let previousDate,
           (previousVenue != venue || previousDate != date) {
            var changed: [String] = []
            if previousVenue != venue {
                changed.append("venue")
            }
            if previousDate != date {
                changed.append("date/time")
            }
            await pushNotification(
                uid: uid,
                eventId: eventId,
                eventTitle: reminder.eventTitle,
                kind: "EVENT_DETAILS_CHANGED",
                message: "Event \(changed.joined(separator: " and ")) changed. Please review updated details.",
                dedupeKey: "DETAILS|\(eventId)|\(venue)|\(date)"
            )
        }

        if status != (previousStatus ?? status) {
            await pushNotification(
                uid: uid,
                eventId: eventId,
                eventTitle: reminder.eventTitle,
                kind: "STATUS_CHANGE",
                message: "Event status updated to \(status.replacingOccurrences(of: "_", with: " ")).",
                dedupeKey: "STATUS|\(eventId)|\(status)"
            )
        }

        await updateWatchState(
            uid: uid,
            eventId: eventId,
            upvotes: upvotes,
            comments: comments,
            replies: replies,
            status: status,
            venue: venue,
            date: date
        )
    }

    private func updateWatchState(
        uid: String,
        eventId: String,
        upvotes: Int,
        comments: Int,
        replies: Int,
        status: String,
        venue: String,
        date: String
    ) async {
        do {
            try await db.collection("user_event_reminders").document(uid)
                .collection("items").document(eventId)
                .setData([
                    "lastSeenUpvoteCount": upvotes,
                    "lastSeenCommentCount": comments,
                    "lastSeenReplyCount": replies,
                    "lastSeenStatus": status,
                    "lastSeenVenue": venue,
                    "lastSeenDate": date,
                    "lastSeenUpvoteObservedAt": Timestamp(date: Date()),
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            errorMessage = "Failed to persist watch state."
        }
    }

    private func pushNotification(
        uid: String,
        eventId: String,
        eventTitle: String,
        kind: String,
        message: String,
        targetCommentId: String? = nil,
        targetReplyId: String? = nil,
        dedupeKey: String? = nil
    ) async {
        do {
            if let dedupeKey {
                let existing = try await db.collection("user_notifications").document(uid)
                    .collection("items")
                    .whereField("dedupeKey", isEqualTo: dedupeKey)
                    .limit(to: 1)
                    .getDocuments()
                if !existing.documents.isEmpty {
                    return
                }
            }

            var payload: [String: Any] = [
                "eventId": eventId,
                "eventTitle": eventTitle,
                "kind": kind,
                "message": message,
                "createdAt": FieldValue.serverTimestamp()
            ]
            if let targetCommentId {
                payload["targetCommentId"] = targetCommentId
            }
            if let targetReplyId {
                payload["targetReplyId"] = targetReplyId
            }
            if let dedupeKey {
                payload["dedupeKey"] = dedupeKey
            }

            try await db.collection("user_notifications").document(uid)
                .collection("items")
                .addDocument(data: payload)
        } catch {
            errorMessage = "Failed to create notification item."
        }
    }

    private func notifyIfCommentOnOwnEvent(uid: String, eventId: String, comment: EventComment) async {
        do {
            let eventSnapshot = try await db.collection("events").document(eventId).getDocument()
            guard let eventData = eventSnapshot.data() else { return }
            guard let creatorUid = eventData["creatorUid"] as? String, creatorUid == uid else { return }

            let eventTitle = eventData["title"] as? String ?? reminderLookup[eventId]?.eventTitle ?? "Event"
            await pushNotification(
                uid: uid,
                eventId: eventId,
                eventTitle: eventTitle,
                kind: "NEW_COMMENT_ON_YOUR_EVENT",
                message: "\(comment.authorName) commented on your event.",
                targetCommentId: comment.id,
                dedupeKey: "COMMENT_ON_OWN|\(eventId)|\(comment.id ?? "")"
            )
        } catch {
            errorMessage = "Failed to evaluate event comment notification."
        }
    }

    private func ensureReplyWatcher(uid: String, eventId: String, commentId: String, watchStartedAt: Date) {
        let key = "\(eventId)|\(commentId)"
        guard replyWatchers[key] == nil else { return }

        replyWatchers[key] = db.collection("events").document(eventId)
            .collection("comments").document(commentId)
            .collection("replies")
            .order(by: "createdAt", descending: true)
            .limit(to: 120)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor in
                    guard self.activeUID == uid else { return }

                    for change in snapshot?.documentChanges ?? [] {
                        guard change.type == .added,
                              let reply = try? change.document.data(as: EventReply.self),
                              reply.authorUid != uid,
                              reply.createdAt.dateValue() > watchStartedAt else { continue }

                        await self.pushNotification(
                            uid: uid,
                            eventId: eventId,
                            eventTitle: self.reminderLookup[eventId]?.eventTitle ?? "Event",
                            kind: "REPLY_TO_YOUR_COMMENT",
                            message: "\(reply.authorName) replied to your comment.",
                            targetCommentId: commentId,
                            targetReplyId: reply.id,
                            dedupeKey: "REPLY_TO_YOU|\(eventId)|\(commentId)|\(reply.id ?? "")"
                        )
                    }
                }
            }
    }

    private func formatCompactCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fm", Double(value) / 1_000_000.0)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000.0)
        }
        return "\(value)"
    }
}
