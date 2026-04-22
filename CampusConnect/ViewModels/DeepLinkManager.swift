import Foundation
import Combine

@MainActor
final class DeepLinkManager: ObservableObject {
    @Published var pendingEventId: String?
    @Published var pendingCommentId: String?
    @Published var pendingReplyId: String?

    func handle(_ url: URL) {
        guard url.scheme == "campusconnect" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard url.host == "event", let eventId = parts.first else { return }
        pendingEventId = eventId
        pendingCommentId = nil
        pendingReplyId = nil
    }

    func openFromNotification(eventId: String, commentId: String? = nil, replyId: String? = nil) {
        pendingEventId = eventId
        pendingCommentId = commentId
        pendingReplyId = replyId
    }

    func clear() {
        pendingEventId = nil
        pendingCommentId = nil
        pendingReplyId = nil
    }
}
