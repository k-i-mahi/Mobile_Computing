import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class CommentThreadViewModel: ObservableObject {
    @Published var comments: [EventComment] = []
    @Published var repliesByComment: [String: [EventReply]] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var commentsListener: ListenerRegistration?
    private var repliesListeners: [String: ListenerRegistration] = [:]

    deinit {
        commentsListener?.remove()
        repliesListeners.values.forEach { $0.remove() }
    }

    func start(eventId: String) {
        commentsListener?.remove()
        isLoading = true
        commentsListener = db.collection("events").document(eventId)
            .collection("comments")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.comments = snapshot?.documents.compactMap { try? $0.data(as: EventComment.self) } ?? []
                }
            }
    }

    func stop() {
        commentsListener?.remove()
        commentsListener = nil
        repliesListeners.values.forEach { $0.remove() }
        repliesListeners = [:]
    }

    func watchReplies(eventId: String, commentId: String) {
        guard repliesListeners[commentId] == nil else { return }

        repliesListeners[commentId] = db.collection("events").document(eventId)
            .collection("comments").document(commentId)
            .collection("replies")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    self?.repliesByComment[commentId] = snapshot?.documents.compactMap { try? $0.data(as: EventReply.self) } ?? []
                }
            }
    }

    func addComment(eventId: String, uid: String, authorName: String, text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let payload = EventComment(
            authorUid: uid,
            authorName: authorName,
            text: trimmed,
            createdAt: Timestamp(date: Date()),
            updatedAt: nil,
            status: "ACTIVE",
            replyCount: 0
        )

        do {
            let eventRef = db.collection("events").document(eventId)
            let commentRef = eventRef.collection("comments").document()
            let commenterRef = eventRef.collection("commenters").document(uid)
            let now = Timestamp(date: Date())

            _ = try await db.runTransaction { tx, errorPointer in
                let commenterExists: Bool
                do {
                    commenterExists = try tx.getDocument(commenterRef).exists
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                tx.setData([
                    "authorUid": payload.authorUid,
                    "authorName": payload.authorName,
                    "text": payload.text,
                    "createdAt": payload.createdAt,
                    "updatedAt": NSNull(),
                    "status": payload.status ?? "ACTIVE",
                    "replyCount": payload.replyCount ?? 0
                ], forDocument: commentRef)

                var eventUpdates: [String: Any] = [
                    "commentCount": FieldValue.increment(Int64(1)),
                    "updatedAt": now
                ]

                if !commenterExists {
                    tx.setData([
                        "uid": uid,
                        "authorName": authorName,
                        "firstCommentId": commentRef.documentID,
                        "createdAt": now
                    ], forDocument: commenterRef)
                    eventUpdates["uniqueCommenterCount"] = FieldValue.increment(Int64(1))
                }

                tx.updateData(eventUpdates, forDocument: eventRef)
                return nil
            }
            await ClientNotificationService.shared.notifyEventOwnerOfComment(
                eventId: eventId,
                commentId: commentRef.documentID,
                actorUid: uid,
                actorName: authorName
            )
        } catch {
            errorMessage = "Failed to post comment. Please try again."
        }
    }

    func addReply(eventId: String, commentId: String, uid: String, authorName: String, text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let parentSnapshot = try await db.collection("events").document(eventId)
                .collection("comments").document(commentId)
                .getDocument()
            if let parentAuthorUID = parentSnapshot.data()?["authorUid"] as? String,
               parentAuthorUID == uid {
                errorMessage = "You can't reply to your own comment."
                return
            }
        } catch {
            errorMessage = "Unable to validate reply target."
            return
        }

        let payload = EventReply(
            authorUid: uid,
            authorName: authorName,
            text: trimmed,
            createdAt: Timestamp(date: Date()),
            updatedAt: nil,
            status: "ACTIVE"
        )

        let commentRef = db.collection("events").document(eventId).collection("comments").document(commentId)
        let eventRef = db.collection("events").document(eventId)
        let replyRef = commentRef.collection("replies").document()

        do {
            _ = try await db.runTransaction { tx, _ in
                tx.setData([
                    "authorUid": payload.authorUid,
                    "authorName": payload.authorName,
                    "text": payload.text,
                    "createdAt": payload.createdAt,
                    "updatedAt": NSNull(),
                    "status": payload.status ?? "ACTIVE"
                ], forDocument: replyRef)
                tx.updateData(["replyCount": FieldValue.increment(Int64(1))], forDocument: commentRef)
                tx.updateData([
                    "replyCount": FieldValue.increment(Int64(1)),
                    "updatedAt": Timestamp(date: Date())
                ], forDocument: eventRef)
                return nil
            }
            await ClientNotificationService.shared.notifyCommentAuthorOfReply(
                eventId: eventId,
                commentId: commentId,
                replyId: replyRef.documentID,
                actorUid: uid,
                actorName: authorName
            )
        } catch {
            errorMessage = "Failed to post reply. Please try again."
        }
    }

    func removeOwnComment(eventId: String, comment: EventComment, uid: String, isAdmin: Bool) async {
        guard let id = comment.id else { return }
        guard isAdmin || comment.authorUid == uid else {
            errorMessage = "You are not allowed to delete this comment."
            return
        }
        if comment.isRemoved {
            return
        }

        do {
            let eventRef = db.collection("events").document(eventId)
            let commentRef = eventRef.collection("comments").document(id)
            _ = try await db.runTransaction { tx, _ in
                tx.setData([
                    "status": isAdmin ? "REMOVED_BY_ADMIN" : "REMOVED",
                    "text": "",
                    "updatedAt": Timestamp(date: Date())
                ], forDocument: commentRef, merge: true)

                tx.updateData([
                    "commentCount": FieldValue.increment(Int64(-1)),
                    "updatedAt": Timestamp(date: Date())
                ], forDocument: eventRef)
                return nil
            }
        } catch {
            errorMessage = "Failed to remove comment."
        }
    }

    func reportComment(eventId: String, commentId: String, reporterUid: String, reason: String, description: String) async {
        do {
            let commentSnapshot = try await db.collection("events").document(eventId)
                .collection("comments").document(commentId)
                .getDocument()
            let commentData = commentSnapshot.data() ?? [:]
            let authorUid = commentData["authorUid"] as? String ?? ""
            if authorUid == reporterUid {
                errorMessage = "You can't report your own comment."
                return
            }

            let reportRef = db.collection("reports").document()
            let caseRef = db.collection("moderation_cases").document()

            let reportData: [String: Any] = [
                "targetType": "COMMENT",
                "targetId": commentId,
                "eventId": eventId,
                "targetOwnerUid": authorUid,
                "targetTitle": commentData["authorName"] as? String ?? "Comment",
                "targetPreview": commentData["text"] as? String ?? "",
                "reporterUid": reporterUid,
                "reason": reason,
                "description": description,
                "linkedCaseId": caseRef.documentID,
                "status": "OPEN",
                "createdAt": Timestamp(date: Date())
            ]

            let batch = db.batch()
            batch.setData(reportData, forDocument: reportRef)
            batch.setData([
                "reporterUid": reporterUid,
                "targetType": "COMMENT",
                "targetId": commentId,
                "eventId": eventId,
                "linkedReportId": reportRef.documentID,
                "reason": reason,
                "status": "OPEN",
                "createdAt": Timestamp(date: Date())
            ], forDocument: caseRef)
            try await batch.commit()
        } catch {
            errorMessage = "Report submission failed."
        }
    }

    func reportReply(
        eventId: String,
        commentId: String,
        replyId: String,
        reporterUid: String,
        reason: String,
        description: String
    ) async {
        do {
            let replySnapshot = try await db.collection("events").document(eventId)
                .collection("comments").document(commentId)
                .collection("replies").document(replyId)
                .getDocument()
            let replyData = replySnapshot.data() ?? [:]
            let authorUid = replyData["authorUid"] as? String ?? ""
            if authorUid == reporterUid {
                errorMessage = "You can't report your own reply."
                return
            }

            let reportRef = db.collection("reports").document()
            let caseRef = db.collection("moderation_cases").document()
            let reportData: [String: Any] = [
                "targetType": "REPLY",
                "targetId": replyId,
                "eventId": eventId,
                "parentCommentId": commentId,
                "targetOwnerUid": authorUid,
                "targetTitle": replyData["authorName"] as? String ?? "Reply",
                "targetPreview": replyData["text"] as? String ?? "",
                "reporterUid": reporterUid,
                "reason": reason,
                "description": description,
                "linkedCaseId": caseRef.documentID,
                "status": "OPEN",
                "createdAt": Timestamp(date: Date())
            ]

            let batch = db.batch()
            batch.setData(reportData, forDocument: reportRef)
            batch.setData([
                "reporterUid": reporterUid,
                "targetType": "REPLY",
                "targetId": replyId,
                "eventId": eventId,
                "parentCommentId": commentId,
                "linkedReportId": reportRef.documentID,
                "reason": reason,
                "status": "OPEN",
                "createdAt": Timestamp(date: Date())
            ], forDocument: caseRef)
            try await batch.commit()
        } catch {
            errorMessage = "Reply report submission failed."
        }
    }
}
