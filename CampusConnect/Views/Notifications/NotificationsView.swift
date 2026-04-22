import SwiftUI
import FirebaseCore

struct NotificationsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @EnvironmentObject var vm: NotificationsViewModel
    @Environment(\.openURL) private var openURL
    @State private var isKuetMailExpanded = true

    var body: some View {
        Group {
            if vm.isLoading && vm.reminders.isEmpty && vm.activityItems.isEmpty && vm.mailItems.isEmpty {
                LoadingView(message: "Loading notifications...")
            } else if vm.reminders.isEmpty && vm.activityItems.isEmpty && vm.mailItems.isEmpty {
                EmptyStateView(
                    icon: "bell.badge",
                    title: "No Notifications Yet",
                    message: "Turn on event notifications to receive live updates and reminders.",
                    buttonTitle: nil,
                    action: nil
                )
            } else {
                List {
                    if !vm.reminders.isEmpty {
                        Section("Event Reminders") {
                            ForEach(vm.reminders) { reminder in
                                reminderRow(reminder)
                            }
                        }
                    }

                    if !vm.activityItems.isEmpty {
                        Section("Live Event Updates") {
                            ForEach(vm.activityItems) { item in
                                activityRow(item)
                            }
                        }
                    }

                    if !vm.mailItems.isEmpty {
                        Section {
                            if isKuetMailExpanded {
                                ForEach(vm.mailItems) { item in
                                    mailRow(item)
                                }
                            }
                        } header: {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isKuetMailExpanded.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("kuet mail")
                                    Spacer()
                                    Image(systemName: isKuetMailExpanded ? "chevron.down" : "chevron.right")
                                        .font(.caption.weight(.semibold))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Notifications")
        .alert("Notification Permission Denied", isPresented: $vm.permissionDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your event preference was saved in CampusConnect. Enable notifications from iOS Settings to receive device alerts.")
        }
    }

    @ViewBuilder
    private func reminderRow(_ reminder: UserEventReminder) -> some View {
        HStack(spacing: 12) {
            Button {
                deepLinkManager.openFromNotification(eventId: reminder.eventId)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(reminder.eventTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Status: \(reminder.statusText)")
                            .font(.caption)
                            .foregroundStyle((reminder.isEnabled && !reminder.isEventExpired) ? Constants.Colors.success : .secondary)
                        Text("Next: \(reminder.nextReminderText)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)

            if reminder.isEventExpired {
                Text("Expired")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                Toggle("", isOn: Binding(
                    get: { reminder.isEnabled },
                    set: { value in
                        Task {
                            guard let uid = authViewModel.currentUID else { return }
                            let fallbackDate = reminder.eventDate?.dateValue()
                                ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())
                                ?? Date()
                            await vm.setReminder(
                                uid: uid,
                                eventId: reminder.eventId,
                                eventTitle: reminder.eventTitle,
                                eventDate: fallbackDate,
                                enabled: value,
                                offsetHours: reminder.reminderOffsetHours
                            )
                        }
                    }
                ))
                .labelsHidden()
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func activityRow(_ item: UserEventNotification) -> some View {
        Button {
            deepLinkManager.openFromNotification(
                eventId: item.eventId,
                commentId: item.targetCommentId,
                replyId: item.targetReplyId
            )
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.iconName)
                    .font(.subheadline)
                    .foregroundStyle(tint(for: item))
                    .frame(width: 22, height: 22)
                    .padding(8)
                    .background(tint(for: item).opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.eventTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(item.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.createdDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func mailRow(_ item: NoticeBoardItem) -> some View {
        Button {
            openMail(item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "envelope.badge.fill")
                    .font(.subheadline)
                    .foregroundStyle(Constants.Colors.brandGradientStart)
                    .frame(width: 22, height: 22)
                    .padding(8)
                    .background(Constants.Colors.brandGradientStart.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("You have a new email on \"\(item.title)\"")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text("From: \(item.senderText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.publishedDateText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()

                Image(systemName: "arrow.up.forward.app")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func openMail(_ item: NoticeBoardItem) {
        let fallbackURL = URL(string: "https://mail.google.com/")!
        let destinationURL = URL(string: item.originalUrl) ?? fallbackURL
        openURL(destinationURL) { accepted in
            if !accepted {
                openURL(fallbackURL)
            }
        }
    }

    private func tint(for item: UserEventNotification) -> Color {
        switch item.kind {
        case "INTEREST_SPIKE":
            return Constants.Colors.warning
        case "NEW_DISCUSSION":
            return Constants.Colors.accent
        case "REPLY_TO_YOUR_COMMENT":
            return Constants.Colors.accent
        case "NEW_COMMENT_ON_YOUR_EVENT":
            return Constants.Colors.warning
        case "UPVOTE_ON_YOUR_EVENT":
            return Constants.Colors.warning
        case "EVENT_DETAILS_CHANGED":
            return Constants.Colors.danger
        case "STATUS_CHANGE":
            return Constants.Colors.success
        default:
            return Constants.Colors.brandGradientStart
        }
    }
}
