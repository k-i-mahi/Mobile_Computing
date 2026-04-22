import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class NoticeBoardViewModel: ObservableObject {
    @Published var items: [NoticeBoardItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var kuetListener: ListenerRegistration?

    deinit {
        kuetListener?.remove()
    }

    func startListening() {
        stopListening()
        isLoading = true
        errorMessage = nil

        kuetListener = db.collection("notice_board_items")
            .order(by: "publishedAt", descending: true)
            .limit(to: 80)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = "KUET notice source unavailable. Showing cached results when available."
                        print(error.localizedDescription)
                        return
                    }

                    self.items = (snapshot?.documents.compactMap { try? $0.data(as: NoticeBoardItem.self) } ?? [])
                        .filter(\.isOfficialKUETNotice)
                        .sorted {
                            let lhs = $0.publishedAt?.dateValue() ?? $0.syncedAt?.dateValue() ?? .distantPast
                            let rhs = $1.publishedAt?.dateValue() ?? $1.syncedAt?.dateValue() ?? .distantPast
                            return lhs > rhs
                        }
                }
            }
    }

    func stopListening() {
        kuetListener?.remove()
        kuetListener = nil
    }
}
