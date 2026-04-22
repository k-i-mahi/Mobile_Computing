import SwiftUI
import Combine
import FirebaseFirestore

struct AdminCommentModerationView: View {
    @StateObject private var vm = AdminCommentModerationViewModel()

    var body: some View {
        List {
            ForEach(vm.items, id: \.id) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.eventTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.commentText)
                        .font(.subheadline)
                    HStack {
                        Text("by \(item.authorName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Remove") {
                            Task { await vm.remove(item: item) }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Constants.Colors.danger)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Comment Moderation")
        .task { await vm.fetch() }
    }
}

private struct ModerateCommentItem: Identifiable {
    let id: String
    let eventId: String
    let eventTitle: String
    let commentText: String
    let authorName: String
}

@MainActor
private final class AdminCommentModerationViewModel: ObservableObject {
    @Published var items: [ModerateCommentItem] = []

    private let db = Firestore.firestore()

    func fetch() async {
        do {
            let events = try await db.collection("events")
                .whereField("status", isEqualTo: EventLifecycleStatus.approved.rawValue)
                .limit(to: 20)
                .getDocuments()

            var result: [ModerateCommentItem] = []
            for eventDoc in events.documents {
                let eventData = eventDoc.data()
                let eventTitle = eventData["title"] as? String ?? "Event"
                let comments = try await db.collection("events").document(eventDoc.documentID)
                    .collection("comments")
                    .order(by: "createdAt", descending: true)
                    .limit(to: 4)
                    .getDocuments()

                for comment in comments.documents {
                    let data = comment.data()
                    result.append(
                        ModerateCommentItem(
                            id: comment.documentID,
                            eventId: eventDoc.documentID,
                            eventTitle: eventTitle,
                            commentText: data["text"] as? String ?? "",
                            authorName: data["authorName"] as? String ?? "Unknown"
                        )
                    )
                }
            }
            items = result
        } catch {
            items = []
        }
    }

    func remove(item: ModerateCommentItem) async {
        do {
            try await db.collection("events").document(item.eventId)
                .collection("comments").document(item.id)
                .setData([
                    "status": "REMOVED_BY_ADMIN",
                    "text": "",
                    "updatedAt": Timestamp(date: Date())
                ], merge: true)
            await fetch()
        } catch {
            // no-op
        }
    }
}
