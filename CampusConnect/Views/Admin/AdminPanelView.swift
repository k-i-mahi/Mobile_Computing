// ============================================================
// AdminPanelView.swift
// Admin control panel: users, events, and broadcast notifications
// ============================================================

import SwiftUI

struct AdminPanelView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var adminVM = AdminViewModel()
    @State private var selectedTab = 0
    @State private var showBroadcastSheet = false

    var body: some View {
        Group {
            if authViewModel.role != .admin {
                accessDeniedView
            } else {
                adminContent
            }
        }
        .navigationTitle("Admin Panel")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showBroadcastSheet = true
                } label: {
                    Image(systemName: "megaphone.fill")
                        .foregroundStyle(Constants.Colors.brandGradientStart)
                }
            }
        }
        .sheet(isPresented: $showBroadcastSheet) {
            BroadcastNotificationSheet(adminVM: adminVM)
        }
        .alert("Success", isPresented: Binding(
            get: { adminVM.successMessage != nil },
            set: { if !$0 { adminVM.successMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(adminVM.successMessage ?? "")
        }
        .alert("Error", isPresented: Binding(
            get: { adminVM.errorMessage != nil },
            set: { if !$0 { adminVM.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(adminVM.errorMessage ?? "")
        }
        .task {
            await adminVM.loadUsers()
            await adminVM.loadPendingEvents()
        }
    }

    // MARK: - Admin Content

    private var adminContent: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedTab) {
                Text("Users").tag(0)
                Text("Events (\(adminVM.pendingEvents.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if adminVM.isLoading {
                LoadingView(message: "Loading…")
            } else if selectedTab == 0 {
                usersTab
            } else {
                eventsTab
            }
        }
    }

    // MARK: - Users Tab

    private var usersTab: some View {
        List(adminVM.users) { user in
            AdminUserRowView(user: user, adminVM: adminVM)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if adminVM.users.isEmpty {
                EmptyStateView(icon: "person.3", title: "No users found", message: "The user list is empty.", buttonTitle: nil, action: nil)
            }
        }
    }

    // MARK: - Events Tab

    private var eventsTab: some View {
        List(adminVM.pendingEvents) { event in
            AdminEventRowView(event: event, adminVM: adminVM)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if adminVM.pendingEvents.isEmpty {
                EmptyStateView(icon: "checkmark.seal", title: "All clear", message: "No pending events to review.", buttonTitle: nil, action: nil)
            }
        }
    }

    // MARK: - Access Denied

    private var accessDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 52))
                .foregroundStyle(Constants.Colors.brandGradientStart)
            Text("Admin Access Only")
                .font(.title2.weight(.bold))
            Text("You don't have permission to view this page.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - User Row

struct AdminUserRowView: View {
    let user: UserProfile
    let adminVM: AdminViewModel
    @State private var showActions = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Constants.Colors.brandGradientStart.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(user.displayName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(Constants.Colors.brandGradientStart)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    statusBadge(user.accountStatus ?? UserRestrictionStatus.active.rawValue)
                    roleBadge(user.role ?? AppUserRole.user.rawValue)
                }
            }
            Spacer()
            Button { showActions = true } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .confirmationDialog("Manage \(user.displayName)", isPresented: $showActions, titleVisibility: .visible) {
            Button("Issue Warning") {
                Task { await adminVM.warnUser(uid: user.uid) }
            }
            Button("Restrict Comments") {
                Task { await adminVM.updateUserStatus(uid: user.uid, status: .commentRestricted) }
            }
            Button("Restrict Events") {
                Task { await adminVM.updateUserStatus(uid: user.uid, status: .eventRestricted) }
            }
            Button("Promote to Admin") {
                Task { await adminVM.promoteToAdmin(uid: user.uid) }
            }
            Button("Restore Active", role: .none) {
                Task { await adminVM.updateUserStatus(uid: user.uid, status: .active) }
            }
            Button("Ban User", role: .destructive) {
                Task { await adminVM.updateUserStatus(uid: user.uid, status: .banned) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status == "active" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
            .foregroundStyle(status == "active" ? Color.green : Color.orange)
            .clipShape(Capsule())
    }

    private func roleBadge(_ role: String) -> some View {
        Text(role.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(role == "admin" ? Constants.Colors.brandGradientStart.opacity(0.15) : Color.gray.opacity(0.1))
            .foregroundStyle(role == "admin" ? Constants.Colors.brandGradientStart : Color.secondary)
            .clipShape(Capsule())
    }
}

// MARK: - Event Row

struct AdminEventRowView: View {
    let event: FirestoreEvent
    let adminVM: AdminViewModel
    @State private var showRejectInput = false
    @State private var rejectionReason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.title)
                .font(.subheadline.weight(.semibold))
            Text(event.organizerName)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Approve") {
                    Task {
                        guard let id = event.id else { return }
                        await adminVM.approveEvent(eventId: id)
                    }
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(Capsule())

                Button("Reject") { showRejectInput = true }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.12))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .alert("Rejection Reason", isPresented: $showRejectInput) {
            TextField("Reason", text: $rejectionReason)
            Button("Confirm", role: .destructive) {
                Task {
                    guard let id = event.id else { return }
                    await adminVM.rejectEvent(eventId: id, reason: rejectionReason)
                    rejectionReason = ""
                }
            }
            Button("Cancel", role: .cancel) { rejectionReason = "" }
        } message: {
            Text("Explain why this event is being rejected.")
        }
    }
}

// MARK: - Broadcast Sheet

struct BroadcastNotificationSheet: View {
    @ObservedObject var adminVM: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var body = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Notification Content") {
                    TextField("Title", text: $title)
                    TextField("Body message", text: $body, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section {
                    Text("This will be sent to ALL users immediately.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Broadcast Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task {
                            await adminVM.sendBroadcastNotification(title: title, body: body)
                            if adminVM.errorMessage == nil { dismiss() }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || body.trimmingCharacters(in: .whitespaces).isEmpty || adminVM.isLoading)
                }
            }
        }
    }
}
