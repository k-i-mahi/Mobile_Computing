// ============================================================
// NotificationsView.swift
// In-app notification feed with read/unread state and delete
// ============================================================

import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var notificationsVM: NotificationsViewModel

    var body: some View {
        Group {
            if notificationsVM.isLoading {
                LoadingView(message: "Loading notifications…")
            } else if notificationsVM.notifications.isEmpty {
                EmptyStateView(
                    icon: "bell.slash",
                    title: "No notifications yet",
                    message: "You'll be notified about event updates, RSVPs, and admin actions here.",
                    buttonTitle: nil,
                    action: nil
                )
            } else {
                notificationList
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !notificationsVM.notifications.filter({ !$0.isRead }).isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mark All Read") {
                        HapticManager.impact(.light)
                        notificationsVM.markAllRead()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Constants.Colors.brandGradientStart)
                }
            }
        }
    }

    // MARK: - List

    private var notificationList: some View {
        List {
            ForEach(notificationsVM.notifications) { notification in
                NotificationRowView(notification: notification)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .onTapGesture {
                        if !notification.isRead {
                            notificationsVM.markRead(notification)
                        }
                    }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    notificationsVM.delete(notificationsVM.notifications[index])
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Row

struct NotificationRowView: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            iconBadge
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
                    .foregroundStyle(.primary)
                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(notification.createdAt.dateValue(), style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if !notification.isRead {
                Circle()
                    .fill(Constants.Colors.brandGradientStart)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            notification.isRead
                ? Color(.secondarySystemGroupedBackground)
                : Constants.Colors.brandGradientStart.opacity(0.07)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(notification.isRead ? Color.clear : Constants.Colors.brandGradientStart.opacity(0.2), lineWidth: 1)
        )
    }

    private var iconBadge: some View {
        Image(systemName: notification.typeIcon)
            .font(.title3)
            .foregroundStyle(Constants.Colors.brandGradientStart)
            .frame(width: 36, height: 36)
            .background(Constants.Colors.brandGradientStart.opacity(0.12))
            .clipShape(Circle())
    }
}
