import SwiftUI
import Combine
import FirebaseFirestore

struct UpvoteViewerView: View {
    let eventId: String
    let eventTitle: String

    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = UpvoteViewerViewModel()

    var body: some View {
        Group {
            if vm.isLoading {
                LoadingView(message: "Loading upvote users...")
            } else if vm.upvoters.isEmpty {
                EmptyStateView(
                    icon: "hand.thumbsup",
                    title: "No Upvotes Yet",
                    message: "No users have upvoted this event yet.",
                    buttonTitle: nil,
                    action: nil
                )
            } else {
                List(vm.upvoters) { user in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text(user.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Upvote Users")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Back to Event", systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                }
            }
            ToolbarItem(placement: .principal) {
                Text(eventTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .task { await vm.load(eventId: eventId) }
    }
}

@MainActor
private final class UpvoteViewerViewModel: ObservableObject {
    @Published var upvoters: [UpvoteUserItem] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    func load(eventId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("events").document(eventId)
                .collection("upvotes")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            let records = snapshot.documents.compactMap { document -> String? in
                let data = document.data()
                let uid = (data["uid"] as? String) ?? document.documentID
                guard !uid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return uid
            }

            var items: [UpvoteUserItem] = []
            items.reserveCapacity(records.count)

            for uid in records {
                let profileSnap = try? await db.collection("users").document(uid).getDocument()
                let profileData = profileSnap?.data() ?? [:]
                let displayName = (profileData["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let email = (profileData["email"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

                items.append(
                    UpvoteUserItem(
                        uid: uid,
                        displayName: (displayName?.isEmpty == false) ? displayName! : "Unknown User",
                        email: (email?.isEmpty == false) ? email! : "No email available"
                    )
                )
            }

            upvoters = items
        } catch {
            upvoters = []
        }
    }
}

private struct UpvoteUserItem: Identifiable {
    let uid: String
    let displayName: String
    let email: String

    var id: String { uid }
}
