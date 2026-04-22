import SwiftUI
import Combine
import FirebaseFirestore

struct AdminReportsQueueView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = AdminReportsQueueViewModel()

    var body: some View {
        Group {
            if vm.isLoading && vm.reports.isEmpty {
                LoadingView(message: "Loading reports...")
            } else if vm.reports.isEmpty {
                EmptyStateView(
                    icon: "checkmark.shield",
                    title: "No Open Reports",
                    message: "Reported events and comments will appear here.",
                    buttonTitle: nil,
                    action: nil
                )
            } else {
                List {
                    ForEach(vm.reports) { report in
                        reportRow(report)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Reports Queue")
        .task { vm.start() }
        .onDisappear { vm.stop() }
        .alert("Moderation", isPresented: Binding(
            get: { vm.statusMessage != nil },
            set: { if !$0 { vm.statusMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.statusMessage ?? "")
        }
    }

    private func reportRow(_ report: AdminReportItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(report.targetType)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Constants.Colors.danger.opacity(0.12))
                    .foregroundStyle(Constants.Colors.danger)
                    .clipShape(Capsule())
                Spacer()
                Text(report.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(vm.displayTitle(for: report))
                .font(.subheadline.weight(.semibold))

            Text(report.reason)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Constants.Colors.warning)

            if !report.description.isEmpty {
                Text(report.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !report.targetPreview.isEmpty {
                Text(report.targetPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 8) {
                Button(deleteButtonTitle(for: report), role: .destructive) {
                    Task {
                        await vm.removeTarget(
                            report: report,
                            adminUid: authViewModel.currentUID ?? "admin"
                        )
                    }
                }
                .buttonStyle(.bordered)
                .disabled(vm.actingReportID == report.id)

                Button("Ban User", role: .destructive) {
                    Task {
                        await vm.banTargetOwner(
                            report: report,
                            adminUid: authViewModel.currentUID ?? "admin"
                        )
                    }
                }
                .buttonStyle(.bordered)
                .disabled(vm.actingReportID == report.id)

                Button("Reviewed") {
                    Task {
                        await vm.markReviewed(
                            report: report,
                            adminUid: authViewModel.currentUID ?? "admin"
                        )
                    }
                }
                .buttonStyle(.bordered)
                .disabled(vm.actingReportID == report.id)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 6)
    }

    private func deleteButtonTitle(for report: AdminReportItem) -> String {
        switch report.targetType {
        case "EVENT":
            return "Delete Event"
        case "REPLY":
            return "Delete Reply"
        default:
            return "Delete Comment"
        }
    }
}

private struct AdminReportItem: Identifiable {
    let id: String
    let targetType: String
    let targetId: String
    let eventId: String?
    let parentCommentId: String?
    let targetOwnerUid: String?
    let reporterUid: String
    let targetTitle: String
    let targetPreview: String
    let reason: String
    let description: String
    let linkedCaseId: String?
    let createdAt: Date
}

@MainActor
private final class AdminReportsQueueViewModel: ObservableObject {
    @Published var reports: [AdminReportItem] = []
    @Published var isLoading = false
    @Published var statusMessage: String?
    @Published var actingReportID: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var ownerListeners: [String: ListenerRegistration] = [:]
    @Published private var ownerDisplayNames: [String: String] = [:]

    deinit {
        listener?.remove()
        ownerListeners.values.forEach { $0.remove() }
    }

    func start() {
        listener?.remove()
        isLoading = true
        listener = db.collection("reports")
            .whereField("status", isEqualTo: "OPEN")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.statusMessage = error.localizedDescription
                        self.reports = []
                        return
                    }
                    let mappedReports = snapshot?.documents.map { self.reportItem(from: $0) } ?? []
                    let fetched = mappedReports.sorted { $0.createdAt > $1.createdAt }
                    self.reports = fetched
                    self.syncOwnerDisplayNameListeners(for: Set(fetched.compactMap(\.targetOwnerUid)))
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        ownerListeners.values.forEach { $0.remove() }
        ownerListeners = [:]
        ownerDisplayNames = [:]
    }

    func displayTitle(for report: AdminReportItem) -> String {
        guard let uid = report.targetOwnerUid, !uid.isEmpty else {
            return report.targetTitle
        }
        return ownerDisplayNames[uid] ?? report.targetTitle
    }

    func removeTarget(report: AdminReportItem, adminUid: String) async {
        guard !report.targetId.isEmpty else {
            statusMessage = "This report is missing its target."
            return
        }

        actingReportID = report.id
        defer { actingReportID = nil }

        do {
            let batch = db.batch()
            let action: String

            if report.targetType == "EVENT" {
                let eventRef = db.collection("events").document(report.targetId)
                batch.setData([
                    "status": EventLifecycleStatus.removedByAdmin.rawValue,
                    "removedByAdmin": true,
                    "updatedAt": Timestamp(date: Date())
                ], forDocument: eventRef, merge: true)
                action = "DELETE_REPORTED_EVENT"
            } else if report.targetType == "COMMENT", let eventId = report.eventId {
                let eventRef = db.collection("events").document(eventId)
                let commentRef = eventRef.collection("comments").document(report.targetId)
                let commentSnapshot = try await commentRef.getDocument()
                let eventSnapshot = try await eventRef.getDocument()
                let status = commentSnapshot.data()?["status"] as? String ?? "ACTIVE"
                batch.setData([
                    "status": "REMOVED_BY_ADMIN",
                    "text": "",
                    "updatedAt": Timestamp(date: Date())
                ], forDocument: commentRef, merge: true)
                if status != "REMOVED" && status != "REMOVED_BY_ADMIN" {
                    let currentCount = eventSnapshot.data()?["commentCount"] as? Int ?? 1
                    batch.updateData([
                        "commentCount": max(currentCount - 1, 0),
                        "updatedAt": Timestamp(date: Date())
                    ], forDocument: eventRef)
                }
                action = "DELETE_REPORTED_COMMENT"
            } else if report.targetType == "REPLY",
                      let eventId = report.eventId,
                      let parentCommentId = report.parentCommentId {
                let eventRef = db.collection("events").document(eventId)
                let commentRef = eventRef.collection("comments").document(parentCommentId)
                let replyRef = commentRef.collection("replies").document(report.targetId)
                let eventSnapshot = try await eventRef.getDocument()
                let commentSnapshot = try await commentRef.getDocument()
                let replySnapshot = try await replyRef.getDocument()
                let status = replySnapshot.data()?["status"] as? String ?? "ACTIVE"
                batch.setData([
                    "status": "REMOVED_BY_ADMIN",
                    "text": "",
                    "updatedAt": Timestamp(date: Date())
                ], forDocument: replyRef, merge: true)
                if status != "REMOVED" && status != "REMOVED_BY_ADMIN" {
                    let eventReplyCount = eventSnapshot.data()?["replyCount"] as? Int ?? 1
                    let commentReplyCount = commentSnapshot.data()?["replyCount"] as? Int ?? 1
                    batch.updateData([
                        "replyCount": max(eventReplyCount - 1, 0),
                        "updatedAt": Timestamp(date: Date())
                    ], forDocument: eventRef)
                    batch.updateData([
                        "replyCount": max(commentReplyCount - 1, 0),
                        "updatedAt": Timestamp(date: Date())
                    ], forDocument: commentRef)
                }
                action = "DELETE_REPORTED_REPLY"
            } else {
                statusMessage = "Unsupported report target."
                return
            }

            complete(report: report, batch: batch, adminUid: adminUid, resolution: action)
            try await batch.commit()
            statusMessage = "Moderation action applied."
        } catch {
            statusMessage = "Failed to apply moderation action."
        }
    }

    func banTargetOwner(report: AdminReportItem, adminUid: String) async {
        actingReportID = report.id
        defer { actingReportID = nil }

        do {
            guard let ownerUid = try await resolveTargetOwnerUid(report), !ownerUid.isEmpty else {
                statusMessage = "Could not find the reported user's account."
                return
            }

            let batch = db.batch()
            batch.setData([
                "accountStatus": UserRestrictionStatus.banned.rawValue,
                "bannedAt": Timestamp(date: Date()),
                "updatedAt": Timestamp(date: Date())
            ], forDocument: db.collection("users").document(ownerUid), merge: true)
            complete(report: report, batch: batch, adminUid: adminUid, resolution: "BAN_REPORTED_USER", targetUserUid: ownerUid)
            try await batch.commit()
            statusMessage = "User banned. Their session will update in real time."
        } catch {
            statusMessage = "Failed to ban reported user."
        }
    }

    func markReviewed(report: AdminReportItem, adminUid: String) async {
        actingReportID = report.id
        defer { actingReportID = nil }

        do {
            let batch = db.batch()
            complete(report: report, batch: batch, adminUid: adminUid, resolution: "REVIEWED_NO_ACTION")
            try await batch.commit()
            statusMessage = "Report marked reviewed."
        } catch {
            statusMessage = "Failed to update report."
        }
    }

    private func complete(
        report: AdminReportItem,
        batch: WriteBatch,
        adminUid: String,
        resolution: String,
        targetUserUid: String? = nil
    ) {
        let now = Timestamp(date: Date())
        batch.setData([
            "status": "ACTIONED",
            "resolution": resolution,
            "reviewedByUid": adminUid,
            "reviewedAt": now
        ], forDocument: db.collection("reports").document(report.id), merge: true)

        var actionData: [String: Any] = [
            "action": resolution,
            "reportId": report.id,
            "targetType": report.targetType,
            "targetId": report.targetId,
            "actorUid": adminUid,
            "createdAt": now
        ]
        if let eventId = report.eventId {
            actionData["eventId"] = eventId
        }
        if let parentCommentId = report.parentCommentId {
            actionData["parentCommentId"] = parentCommentId
        }
        if let targetUserUid {
            actionData["targetUserUid"] = targetUserUid
        }
        batch.setData(actionData, forDocument: db.collection("admin_actions").document())

        if let linkedCaseId = report.linkedCaseId, !linkedCaseId.isEmpty {
            batch.setData([
                "status": "ACTIONED",
                "resolution": resolution,
                "reviewedByUid": adminUid,
                "reviewedAt": now
            ], forDocument: db.collection("moderation_cases").document(linkedCaseId), merge: true)
        }
    }

    private func resolveTargetOwnerUid(_ report: AdminReportItem) async throws -> String? {
        if let targetOwnerUid = report.targetOwnerUid, !targetOwnerUid.isEmpty {
            return targetOwnerUid
        }

        if report.targetType == "EVENT" {
            let event = try await db.collection("events").document(report.targetId).getDocument()
            return event.data()?["creatorUid"] as? String
        }

        if report.targetType == "COMMENT", let eventId = report.eventId {
            let comment = try await db.collection("events").document(eventId)
                .collection("comments").document(report.targetId)
                .getDocument()
            return comment.data()?["authorUid"] as? String
        }

        if report.targetType == "REPLY",
           let eventId = report.eventId,
           let parentCommentId = report.parentCommentId {
            let reply = try await db.collection("events").document(eventId)
                .collection("comments").document(parentCommentId)
                .collection("replies").document(report.targetId)
                .getDocument()
            return reply.data()?["authorUid"] as? String
        }

        return nil
    }

    private func reportItem(from document: QueryDocumentSnapshot) -> AdminReportItem {
        let data = document.data()
        let targetType = data["targetType"] as? String ?? "UNKNOWN"
        let fallbackTitle = targetType == "EVENT" ? "Reported Event" : "Reported Comment"
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return AdminReportItem(
            id: document.documentID,
            targetType: targetType,
            targetId: data["targetId"] as? String ?? "",
            eventId: data["eventId"] as? String,
            parentCommentId: data["parentCommentId"] as? String,
            targetOwnerUid: data["targetOwnerUid"] as? String,
            reporterUid: data["reporterUid"] as? String ?? "",
            targetTitle: data["targetTitle"] as? String ?? fallbackTitle,
            targetPreview: data["targetPreview"] as? String ?? "",
            reason: data["reason"] as? String ?? "No reason",
            description: data["description"] as? String ?? "",
            linkedCaseId: data["linkedCaseId"] as? String,
            createdAt: createdAt
        )
    }

    private func syncOwnerDisplayNameListeners(for uids: Set<String>) {
        for staleUID in Set(ownerListeners.keys).subtracting(uids) {
            ownerListeners[staleUID]?.remove()
            ownerListeners[staleUID] = nil
            ownerDisplayNames[staleUID] = nil
        }

        for uid in uids where ownerListeners[uid] == nil {
            ownerListeners[uid] = db.collection("users").document(uid)
                .addSnapshotListener { [weak self] snapshot, _ in
                    Task { @MainActor in
                        guard let self else { return }
                        let data = snapshot?.data() ?? [:]
                        let displayName = (data["displayName"] as? String)?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let email = (data["email"] as? String)?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if let displayName, !displayName.isEmpty {
                            self.ownerDisplayNames[uid] = displayName
                        } else if let email, !email.isEmpty {
                            self.ownerDisplayNames[uid] = email
                        }
                    }
                }
        }
    }
}
