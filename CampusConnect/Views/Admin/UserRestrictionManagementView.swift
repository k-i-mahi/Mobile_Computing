import SwiftUI
import Combine
import FirebaseFirestore

struct UserRestrictionManagementView: View {
    @StateObject private var vm = UserRestrictionManagementViewModel()

    var body: some View {
        List {
            ForEach(vm.users, id: \.uid) { user in
                NavigationLink {
                    UserModerationDetailView(user: user)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(user.displayName.isEmpty ? user.email : user.displayName)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(user.accountStatus ?? UserRestrictionStatus.active.rawValue)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Constants.Colors.warning.opacity(0.14))
                                .clipShape(Capsule())
                        }

                        Text("Warnings: \(user.warningCount ?? 0)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Restrictions")
        .task { vm.start() }
        .onDisappear { vm.stop() }
    }
}

private struct UserModerationDetailView: View {
    let user: UserProfile

    @StateObject private var vm = UserModerationActionViewModel()
    @State private var warningReason = ""
    @State private var restrictionDays = 7

    var body: some View {
        List {
            Section("User") {
                LabeledContent("Name", value: user.displayName.isEmpty ? "N/A" : user.displayName)
                LabeledContent("Email", value: user.email)
                LabeledContent("Warnings", value: "\(user.warningCount ?? 0)")
                LabeledContent("Status", value: user.accountStatus ?? UserRestrictionStatus.active.rawValue)
            }

            Section("Issue Warning") {
                TextField("Reason", text: $warningReason)
                Button("Issue Warning") {
                    Task {
                        await vm.issueWarning(userUid: user.uid, reason: warningReason)
                        warningReason = ""
                    }
                }
                .disabled(warningReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Restrictions") {
                Stepper("Duration: \(restrictionDays) day(s)", value: $restrictionDays, in: 1...30)

                Button("Restrict Comment Access") {
                    Task {
                        await vm.applyRestriction(
                            userUid: user.uid,
                            type: "COMMENT_RESTRICTED",
                            days: restrictionDays
                        )
                    }
                }

                Button("Restrict Event Creation") {
                    Task {
                        await vm.applyRestriction(
                            userUid: user.uid,
                            type: "EVENT_RESTRICTED",
                            days: restrictionDays
                        )
                    }
                }

                Button("Remove Active Restrictions") {
                    Task { await vm.clearRestrictions(userUid: user.uid) }
                }
            }

            Section("Severe Action") {
                Button("Permanently Ban User", role: .destructive) {
                    Task { await vm.banUser(userUid: user.uid) }
                }
            }

            if let status = vm.statusMessage {
                Section {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Moderation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    WarningHistoryView(userUid: user.uid)
                } label: {
                    Text("History")
                }
            }
        }
    }
}

private struct WarningHistoryView: View {
    let userUid: String
    @StateObject private var vm = WarningHistoryViewModel()

    var body: some View {
        List {
            ForEach(vm.items, id: \.id) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.reason)
                        .font(.subheadline.weight(.semibold))
                    Text(item.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Warning History")
        .task { vm.start(userUid: userUid) }
        .onDisappear { vm.stop() }
    }
}

private struct WarningHistoryItem {
    let id: String
    let reason: String
    let createdAt: Date
}

@MainActor
private final class WarningHistoryViewModel: ObservableObject {
    @Published var items: [WarningHistoryItem] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    func start(userUid: String) {
        listener?.remove()
        listener = db.collection("warnings")
            .whereField("userUid", isEqualTo: userUid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    self?.items = snapshot?.documents.map { doc in
                        let data = doc.data()
                        return WarningHistoryItem(
                            id: doc.documentID,
                            reason: data["reason"] as? String ?? "Policy warning",
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        )
                    } ?? []
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
}

@MainActor
private final class UserModerationActionViewModel: ObservableObject {
    @Published var statusMessage: String?

    private let db = Firestore.firestore()

    func issueWarning(userUid: String, reason: String) async {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let now = Timestamp(date: Date())
            try await db.collection("warnings").addDocument(data: [
                "userUid": userUid,
                "reason": trimmed,
                "createdAt": now
            ])

            let userRef = db.collection("users").document(userUid)
            try await userRef.setData([
                "warningCount": FieldValue.increment(Int64(1)),
                "updatedAt": now
            ], merge: true)

            let userSnap = try await userRef.getDocument()
            let updatedWarningCount = userSnap.data()?["warningCount"] as? Int ?? 0

            if updatedWarningCount >= Constants.warningBanThreshold {
                try await userRef.setData([
                    "accountStatus": UserRestrictionStatus.banned.rawValue,
                    "bannedAt": now
                ], merge: true)
            }

            try await db.collection("admin_actions").addDocument(data: [
                "action": "ISSUE_WARNING",
                "targetUserUid": userUid,
                "reason": trimmed,
                "createdAt": now
            ])

            if updatedWarningCount >= Constants.warningBanThreshold {
                try await db.collection("admin_actions").addDocument(data: [
                    "action": "AUTO_BAN_AFTER_WARNINGS",
                    "targetUserUid": userUid,
                    "warningCount": updatedWarningCount,
                    "createdAt": now
                ])
                statusMessage = "Warning issued. User reached threshold and has been permanently banned."
            } else {
                statusMessage = "Warning issued. Current warning count: \(updatedWarningCount)."
            }
        } catch {
            statusMessage = "Failed to issue warning."
        }
    }

    func applyRestriction(userUid: String, type: String, days: Int) async {
        let expiresAt = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        do {
            try await db.collection("restrictions").addDocument(data: [
                "userUid": userUid,
                "type": type,
                "createdAt": Timestamp(date: Date()),
                "expiresAt": Timestamp(date: expiresAt),
                "active": true
            ])

            try await db.collection("users").document(userUid).setData([
                "accountStatus": type
            ], merge: true)

            try await db.collection("admin_actions").addDocument(data: [
                "action": "APPLY_RESTRICTION",
                "targetUserUid": userUid,
                "restrictionType": type,
                "expiresAt": Timestamp(date: expiresAt),
                "createdAt": Timestamp(date: Date())
            ])

            statusMessage = "Restriction applied for \(days) day(s)."
        } catch {
            statusMessage = "Failed to apply restriction."
        }
    }

    func banUser(userUid: String) async {
        do {
            try await db.collection("users").document(userUid).setData([
                "accountStatus": UserRestrictionStatus.banned.rawValue,
                "bannedAt": Timestamp(date: Date())
            ], merge: true)

            try await db.collection("admin_actions").addDocument(data: [
                "action": "BAN_USER",
                "targetUserUid": userUid,
                "createdAt": Timestamp(date: Date())
            ])

            statusMessage = "User has been permanently banned."
        } catch {
            statusMessage = "Failed to ban user."
        }
    }

    func clearRestrictions(userUid: String) async {
        do {
            let active = try await db.collection("restrictions")
                .whereField("userUid", isEqualTo: userUid)
                .whereField("active", isEqualTo: true)
                .getDocuments()

            let batch = db.batch()
            for doc in active.documents {
                batch.setData([
                    "active": false,
                    "clearedAt": Timestamp(date: Date())
                ], forDocument: doc.reference, merge: true)
            }
            batch.setData([
                "accountStatus": UserRestrictionStatus.active.rawValue
            ], forDocument: db.collection("users").document(userUid), merge: true)
            try await batch.commit()

            try await db.collection("admin_actions").addDocument(data: [
                "action": "CLEAR_RESTRICTIONS",
                "targetUserUid": userUid,
                "createdAt": Timestamp(date: Date())
            ])

            statusMessage = "Active restrictions cleared; account restored to ACTIVE."
        } catch {
            statusMessage = "Failed to clear restrictions."
        }
    }
}

@MainActor
private final class UserRestrictionManagementViewModel: ObservableObject {
    @Published var users: [UserProfile] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    func start() {
        listener?.remove()
        listener = db.collection("users")
            .order(by: "warningCount", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    self?.users = snapshot?.documents.compactMap { try? $0.data(as: UserProfile.self) } ?? []
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
}
