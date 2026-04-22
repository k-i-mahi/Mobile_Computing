import SwiftUI
import FirebaseCore

struct CommentsSectionView: View {
    let eventId: String
    let focusCommentId: String?
    let focusReplyId: String?

    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = CommentThreadViewModel()

    @State private var newCommentText = ""
    @State private var replyDraftByComment: [String: String] = [:]
    @State private var expandedRepliesByComment: Set<String> = []
    @State private var reportTargetComment: EventComment?
    @State private var reportTargetReply: ReplyReportTarget?

    init(eventId: String, focusCommentId: String? = nil, focusReplyId: String? = nil) {
        self.eventId = eventId
        self.focusCommentId = focusCommentId
        self.focusReplyId = focusReplyId
    }

    private var canPostComments: Bool {
        authViewModel.accountStatus != .commentRestricted && authViewModel.accountStatus != .banned
    }

    private var previewComments: [EventComment] {
        if focusCommentId != nil || vm.comments.count <= 5 {
            return vm.comments
        }
        return Array(vm.comments.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Label("Comments", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.subheadline.weight(.semibold))
                Text("\(vm.comments.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !vm.comments.isEmpty {
                    NavigationLink {
                        AllCommentsView(
                            eventId: eventId,
                            focusCommentId: focusCommentId,
                            focusReplyId: focusReplyId
                        )
                    } label: {
                        Text("ALL Comments")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Constants.Colors.brandGradientStart)
                }
            }

            composer

            if vm.isLoading && vm.comments.isEmpty {
                ProgressView("Loading comments...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(previewComments) { comment in
                        EventCommentRow(
                            eventId: eventId,
                            comment: comment,
                            vm: vm,
                            replyDraftByComment: $replyDraftByComment,
                            expandedRepliesByComment: $expandedRepliesByComment,
                            onReport: { reportTargetComment = $0 },
                            onReportReply: { comment, reply in
                                reportTargetReply = ReplyReportTarget(comment: comment, reply: reply)
                            }
                        )
                        .id(commentStableID(comment))
                    }

                    if vm.comments.count > 5 && focusCommentId == nil {
                        NavigationLink {
                            AllCommentsView(eventId: eventId)
                        } label: {
                            HStack {
                                Text("ALL Comments")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(vm.comments.count)")
                                    .font(.caption.weight(.semibold))
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                            }
                            .padding(12)
                            .background(Constants.Colors.brandGradientStart.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Constants.Colors.brandGradientStart)
                    }
                }
                .onChange(of: vm.comments) { _, comments in
                    guard let focusCommentId,
                          comments.contains(where: { $0.id == focusCommentId }) else { return }
                    vm.watchReplies(eventId: eventId, commentId: focusCommentId)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(focusCommentId, anchor: .center)
                        }
                    }
                }
                .onChange(of: vm.repliesByComment[focusCommentId ?? ""] ?? []) { _, replies in
                    guard let focusCommentId,
                          let focusReplyId,
                          replies.contains(where: { $0.id == focusReplyId }) else { return }
                    expandedRepliesByComment.insert(focusCommentId)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(replyStableID(focusReplyId), anchor: .center)
                        }
                    }
                }
            }

            if vm.comments.isEmpty && !vm.isLoading {
                Text("No comments yet. Be the first to start discussion.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Constants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius, style: .continuous))
        .onAppear {
            vm.start(eventId: eventId)
        }
        .onDisappear {
            vm.stop()
        }
        .confirmationDialog(
            "Report Comment",
            isPresented: Binding(
                get: { reportTargetComment != nil },
                set: { if !$0 { reportTargetComment = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(Constants.reportCategories, id: \.self) { reason in
                Button(reason) {
                    submitReport(reason: reason)
                }
            }
            Button("Cancel", role: .cancel) {
                reportTargetComment = nil
            }
        } message: {
            Text("Choose a reason. Your report will be sent to admins for review.")
        }
        .confirmationDialog(
            "Report Reply",
            isPresented: Binding(
                get: { reportTargetReply != nil },
                set: { if !$0 { reportTargetReply = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(Constants.reportCategories, id: \.self) { reason in
                Button(reason) {
                    submitReplyReport(reason: reason)
                }
            }
            Button("Cancel", role: .cancel) {
                reportTargetReply = nil
            }
        } message: {
            Text("Choose a reason. Your report will be sent to admins for review.")
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            if !canPostComments {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.bubble.fill")
                    Text("Comment posting is currently restricted for your account.")
                        .lineLimit(2)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Constants.Colors.warning)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Constants.Colors.warning.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            TextField("Share your thoughts...", text: $newCommentText)
                .textFieldStyle(.roundedBorder)
                .disabled(!canPostComments)

            Button {
                Task {
                    guard let uid = authViewModel.currentUID else { return }
                    await vm.addComment(
                        eventId: eventId,
                        uid: uid,
                        authorName: authViewModel.currentDisplayName,
                        text: newCommentText
                    )
                    newCommentText = ""
                }
            } label: {
                Text("Post Comment")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Constants.Colors.brandGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!canPostComments || newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func submitReport(reason: String) {
        Task {
            guard let target = reportTargetComment,
                  let commentId = target.id,
                  let uid = authViewModel.currentUID else { return }
            await vm.reportComment(
                eventId: eventId,
                commentId: commentId,
                reporterUid: uid,
                reason: reason,
                description: "Submitted from Event Comments"
            )
            reportTargetComment = nil
        }
    }

    private func submitReplyReport(reason: String) {
        Task {
            guard let target = reportTargetReply,
                  let commentId = target.comment.id,
                  let replyId = target.reply.id,
                  let uid = authViewModel.currentUID else { return }
            await vm.reportReply(
                eventId: eventId,
                commentId: commentId,
                replyId: replyId,
                reporterUid: uid,
                reason: reason,
                description: "Submitted from Event Comments"
            )
            reportTargetReply = nil
        }
    }
}

private struct AllCommentsView: View {
    let eventId: String
    let focusCommentId: String?
    let focusReplyId: String?

    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = CommentThreadViewModel()
    @State private var replyDraftByComment: [String: String] = [:]
    @State private var expandedRepliesByComment: Set<String> = []
    @State private var reportTargetComment: EventComment?
    @State private var reportTargetReply: ReplyReportTarget?

    init(eventId: String, focusCommentId: String? = nil, focusReplyId: String? = nil) {
        self.eventId = eventId
        self.focusCommentId = focusCommentId
        self.focusReplyId = focusReplyId
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if vm.isLoading && vm.comments.isEmpty {
                        ProgressView("Loading comments...")
                            .padding(.top, 16)
                    } else if vm.comments.isEmpty {
                        Text("No comments yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 16)
                    } else {
                        ForEach(vm.comments) { comment in
                            EventCommentRow(
                                eventId: eventId,
                                comment: comment,
                                vm: vm,
                                replyDraftByComment: $replyDraftByComment,
                                expandedRepliesByComment: $expandedRepliesByComment,
                                onReport: { reportTargetComment = $0 },
                                onReportReply: { comment, reply in
                                    reportTargetReply = ReplyReportTarget(comment: comment, reply: reply)
                                }
                            )
                            .id(commentStableID(comment))
                        }
                    }
                }
                .padding(.horizontal, Constants.Design.horizontalPadding)
                .padding(.vertical, 16)
            }
            .navigationTitle("ALL Comments")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                vm.start(eventId: eventId)
            }
            .onDisappear {
                vm.stop()
            }
            .onChange(of: vm.comments) { _, comments in
                guard let focusCommentId,
                      comments.contains(where: { $0.id == focusCommentId }) else { return }
                vm.watchReplies(eventId: eventId, commentId: focusCommentId)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(focusCommentId, anchor: .center)
                    }
                }
            }
            .onChange(of: vm.repliesByComment[focusCommentId ?? ""] ?? []) { _, replies in
                guard let focusCommentId,
                      let focusReplyId,
                      replies.contains(where: { $0.id == focusReplyId }) else { return }
                expandedRepliesByComment.insert(focusCommentId)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(replyStableID(focusReplyId), anchor: .center)
                    }
                }
            }
        }
        .confirmationDialog(
            "Report Comment",
            isPresented: Binding(
                get: { reportTargetComment != nil },
                set: { if !$0 { reportTargetComment = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(Constants.reportCategories, id: \.self) { reason in
                Button(reason) {
                    submitReport(reason: reason)
                }
            }
            Button("Cancel", role: .cancel) {
                reportTargetComment = nil
            }
        } message: {
            Text("Choose a reason. Your report will be sent to admins for review.")
        }
        .confirmationDialog(
            "Report Reply",
            isPresented: Binding(
                get: { reportTargetReply != nil },
                set: { if !$0 { reportTargetReply = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(Constants.reportCategories, id: \.self) { reason in
                Button(reason) {
                    submitReplyReport(reason: reason)
                }
            }
            Button("Cancel", role: .cancel) {
                reportTargetReply = nil
            }
        } message: {
            Text("Choose a reason. Your report will be sent to admins for review.")
        }
    }

    private func submitReport(reason: String) {
        Task {
            guard let target = reportTargetComment,
                  let commentId = target.id,
                  let uid = authViewModel.currentUID else { return }
            await vm.reportComment(
                eventId: eventId,
                commentId: commentId,
                reporterUid: uid,
                reason: reason,
                description: "Submitted from All Comments"
            )
            reportTargetComment = nil
        }
    }

    private func submitReplyReport(reason: String) {
        Task {
            guard let target = reportTargetReply,
                  let commentId = target.comment.id,
                  let replyId = target.reply.id,
                  let uid = authViewModel.currentUID else { return }
            await vm.reportReply(
                eventId: eventId,
                commentId: commentId,
                replyId: replyId,
                reporterUid: uid,
                reason: reason,
                description: "Submitted from All Comments"
            )
            reportTargetReply = nil
        }
    }
}

private struct EventCommentRow: View {
    let eventId: String
    let comment: EventComment
    @ObservedObject var vm: CommentThreadViewModel
    @Binding var replyDraftByComment: [String: String]
    @Binding var expandedRepliesByComment: Set<String>
    let onReport: (EventComment) -> Void
    let onReportReply: (EventComment, EventReply) -> Void

    @EnvironmentObject var authViewModel: AuthViewModel

    private var canPostComments: Bool {
        authViewModel.accountStatus != .commentRestricted && authViewModel.accountStatus != .banned
    }

    var body: some View {
        let isOwnComment = authViewModel.currentUID == comment.authorUid

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(comment.authorName)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(comment.createdAt.dateValue(), style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(comment.displayText)
                .font(.subheadline)
                .foregroundStyle(comment.isRemoved ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("Reply") {
                    guard let id = comment.id else { return }
                    vm.watchReplies(eventId: eventId, commentId: id)
                    expandedRepliesByComment.insert(id)
                }
                .font(.caption.weight(.semibold))
                .disabled(isOwnComment || !canPostComments || comment.isRemoved)

                Button("Report") {
                    onReport(comment)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Constants.Colors.danger)
                .disabled(isOwnComment || comment.isRemoved)
                .opacity((isOwnComment || comment.isRemoved) ? 0.45 : 1)
                .blur(radius: (isOwnComment || comment.isRemoved) ? 0.7 : 0)

                if (authViewModel.currentUID == comment.authorUid) || (authViewModel.role == .admin) {
                    Button("Delete") {
                        Task {
                            guard let uid = authViewModel.currentUID else { return }
                            await vm.removeOwnComment(
                                eventId: eventId,
                                comment: comment,
                                uid: uid,
                                isAdmin: authViewModel.role == .admin
                            )
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Constants.Colors.warning)
                    .disabled(comment.isRemoved)
                }
            }

            repliesBlock(isOwnComment: isOwnComment)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            guard let commentId = comment.id else { return }
            vm.watchReplies(eventId: eventId, commentId: commentId)
        }
    }

    @ViewBuilder
    private func repliesBlock(isOwnComment: Bool) -> some View {
        if let commentId = comment.id,
           let replies = vm.repliesByComment[commentId] {
            let showAllReplies = expandedRepliesByComment.contains(commentId)
            let visibleReplies = showAllReplies ? replies : Array(replies.prefix(2))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(visibleReplies) { reply in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Constants.Colors.brandGradientStart.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reply.authorName)
                                .font(.caption2.weight(.semibold))
                            Text(reply.displayText)
                                .font(.caption)
                                .foregroundStyle(reply.isRemoved ? .secondary : .primary)
                                .fixedSize(horizontal: false, vertical: true)
                            if authViewModel.currentUID != reply.authorUid && !reply.isRemoved {
                                HStack(spacing: 10) {
                                    Button("Reply") {
                                        expandedRepliesByComment.insert(commentId)
                                    }
                                    .font(.caption2.weight(.semibold))

                                    Button("Report") {
                                        onReportReply(comment, reply)
                                    }
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Constants.Colors.danger)
                                }
                                .padding(.top, 2)
                            }
                        }
                        Spacer()
                    }
                    .id(replyStableID(reply.id))
                }

                if replies.count > 2 {
                    Button(showAllReplies ? "Hide replies" : "Show all replies (\(replies.count))") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if showAllReplies {
                                expandedRepliesByComment.remove(commentId)
                            } else {
                                expandedRepliesByComment.insert(commentId)
                            }
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(.plain)
                }

                if !isOwnComment && !comment.isRemoved {
                    HStack {
                        TextField(
                            "Write a reply...",
                            text: Binding(
                                get: { replyDraftByComment[commentId] ?? "" },
                                set: { replyDraftByComment[commentId] = $0 }
                            )
                        )
                        .textFieldStyle(.roundedBorder)

                        Button("Send") {
                            Task {
                                guard let uid = authViewModel.currentUID else { return }
                                await vm.addReply(
                                    eventId: eventId,
                                    commentId: commentId,
                                    uid: uid,
                                    authorName: authViewModel.currentDisplayName,
                                    text: replyDraftByComment[commentId] ?? ""
                                )
                                replyDraftByComment[commentId] = ""
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .disabled(!canPostComments || (replyDraftByComment[commentId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.leading, 10)
        }
    }
}

private func commentStableID(_ comment: EventComment) -> String {
    if let id = comment.id {
        return id
    }
    let stamp = comment.createdAt.dateValue().timeIntervalSince1970
    return "\(comment.authorUid)-\(Int(stamp))"
}

private func replyStableID(_ replyId: String?) -> String {
    "reply-\(replyId ?? "missing")"
}

private struct ReplyReportTarget: Identifiable {
    let comment: EventComment
    let reply: EventReply

    var id: String {
        "\(comment.id ?? "comment")|\(reply.id ?? "reply")"
    }
}
