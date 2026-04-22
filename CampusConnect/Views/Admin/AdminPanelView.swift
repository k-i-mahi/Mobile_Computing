// ============================================================
// AdminPanelView.swift
// Admin panel for managing all events across the platform
// ============================================================

import SwiftUI

struct AdminPanelView: View {
    @EnvironmentObject var firestoreManager: FirestoreEventManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var searchText = ""
    @State private var showDeleteConfirm = false
    @State private var eventToDelete: FirestoreEvent?
    @State private var appeared = false
    @State private var mode: AdminMode = .approvalQueue
    @State private var rejectTarget: FirestoreEvent?
    @State private var rejectionReason = ""
    @State private var showRejectPrompt = false
    @State private var selectedCategoryFilter: String?
    @State private var selectedCreatorFilter: String?
    @State private var showCategoryFilterPicker = false
    @State private var showCreatorFilterPicker = false
    
    private var filteredEvents: [FirestoreEvent] {
        let source: [FirestoreEvent] = {
            switch mode {
            case .approvalQueue:
                return firestoreManager.allEvents.filter { $0.lifecycleStatus == .pendingApproval }
            case .history:
                return firestoreManager.allEvents.filter { [.approved, .rejected].contains($0.lifecycleStatus) }
            }
        }()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = source

        if !query.isEmpty {
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.venue.lowercased().contains(query) ||
                $0.category.lowercased().contains(query) ||
                $0.creatorEmail.lowercased().contains(query) ||
                ($0.organizerName ?? "").lowercased().contains(query) ||
                ($0.organizationName ?? "").lowercased().contains(query) ||
                ($0.hostEmail ?? "").lowercased().contains(query)
            }
        }

        if let selectedCategoryFilter {
            result = result.filter { $0.category == selectedCategoryFilter }
        }

        if let selectedCreatorFilter {
            result = result.filter { $0.creatorEmail == selectedCreatorFilter }
        }

        return result
    }

    private var pendingApprovalCount: Int {
        firestoreManager.allEvents.filter { $0.lifecycleStatus == .pendingApproval }.count
    }

    private var uniqueCategoryCount: Int {
        Set(firestoreManager.allEvents.map(\.category)).count
    }

    private var uniqueCreatorCount: Int {
        Set(firestoreManager.allEvents.map(\.creatorEmail)).count
    }

    private var allCategories: [String] {
        Array(Set(firestoreManager.allEvents.map(\.category))).sorted()
    }

    private var allCreators: [String] {
        Array(Set(firestoreManager.allEvents.map(\.creatorEmail))).sorted()
    }
    
    var body: some View {
        Group {
            if firestoreManager.isLoading && firestoreManager.allEvents.isEmpty {
                LoadingView(message: "Loading all events…")
            } else {
                mainContent
            }
        }
        .navigationTitle("Admin Panel")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search events, venues, creators…")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    firestoreManager.startListeningAdminAllEvents()
                    HapticManager.selection()
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                }
            }
        }
        .confirmationDialog("Delete Event", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let event = eventToDelete, let id = event.id {
                    Task {
                        try? await firestoreManager.deleteEvent(id: id)
                    }
                }
            }
        } message: {
            Text("This will permanently delete the event. This action cannot be undone.")
        }
        .alert("Reject Event", isPresented: $showRejectPrompt) {
            TextField("Rejection reason", text: $rejectionReason)
            Button("Cancel", role: .cancel) {
                rejectionReason = ""
                rejectTarget = nil
            }
            Button("Reject", role: .destructive) {
                Task {
                    guard let event = rejectTarget,
                          let id = event.id,
                          let adminUID = authViewModel.currentUID,
                          !rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        firestoreManager.errorMessage = "Rejection reason is required."
                        return
                    }
                    try? await firestoreManager.rejectEvent(
                        id: id,
                        reason: rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines),
                        adminUID: adminUID
                    )
                    rejectionReason = ""
                    rejectTarget = nil
                }
            }
        } message: {
            Text("Provide clear feedback so the creator can edit and resubmit.")
        }
        .confirmationDialog("Filter by Category", isPresented: $showCategoryFilterPicker, titleVisibility: .visible) {
            Button("All Categories") {
                selectedCategoryFilter = nil
            }
            ForEach(allCategories, id: \.self) { category in
                Button(category) {
                    selectedCategoryFilter = category
                }
            }
        }
        .confirmationDialog("Filter by Creator", isPresented: $showCreatorFilterPicker, titleVisibility: .visible) {
            Button("All Creators") {
                selectedCreatorFilter = nil
            }
            ForEach(allCreators, id: \.self) { creator in
                Button(creator) {
                    selectedCreatorFilter = creator
                }
            }
        }
        .overlay {
            if let msg = firestoreManager.successMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Constants.Colors.success.gradient, in: Capsule())
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4), value: msg)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        firestoreManager.clearSuccess()
                    }
                }
            }
        }
        .onAppear {
            firestoreManager.startListeningAdminAllEvents()
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) { appeared = true }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            Picker("Admin Mode", selection: $mode) {
                Text("Approval Queue").tag(AdminMode.approvalQueue)
                Text("History").tag(AdminMode.history)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            statsBar
            adminToolGrid

            if filteredEvents.isEmpty {
                adminEmptyState
            } else {
                List {
                    ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, event in
                        VStack(alignment: .leading, spacing: 10) {
                            NavigationLink {
                                EventDetailView(event: event.asEvent)
                            } label: {
                                AdminEventRow(event: event)
                            }
                            .buttonStyle(.plain)

                            if mode == .approvalQueue {
                                HStack(spacing: 10) {
                                    Button {
                                        Task { await approve(event) }
                                    } label: {
                                        Label("Approve", systemImage: "checkmark.circle.fill")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Constants.Colors.success.opacity(0.14))
                                            .foregroundStyle(Constants.Colors.success)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        rejectTarget = event
                                        showRejectPrompt = true
                                    } label: {
                                        Label("Reject", systemImage: "xmark.circle.fill")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Constants.Colors.warning.opacity(0.14))
                                            .foregroundStyle(Constants.Colors.warning)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)

                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .staggeredAppear(index: index, show: appeared)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if mode == .approvalQueue {
                                Button {
                                    Task { await approve(event) }
                                } label: {
                                    Label("Approve", systemImage: "checkmark.circle")
                                }
                                .tint(Constants.Colors.success)

                                Button {
                                    rejectTarget = event
                                    showRejectPrompt = true
                                } label: {
                                    Label("Reject", systemImage: "xmark.circle")
                                }
                                .tint(Constants.Colors.warning)
                            }

                            Button(role: .destructive) {
                                eventToDelete = event
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var statsBar: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            Button {
                selectedCategoryFilter = nil
                selectedCreatorFilter = nil
                HapticManager.selection()
            } label: {
                StatCard(
                    label: "Total Events",
                    value: "\(firestoreManager.allEvents.count)",
                    icon: "calendar",
                    color: Constants.Colors.brandGradientStart
                )
            }
            .buttonStyle(.plain)

            Button {
                showCategoryFilterPicker = true
            } label: {
                StatCard(
                    label: "Categories",
                    value: "\(uniqueCategoryCount)",
                    icon: "tag.fill",
                    color: .purple
                )
            }
            .buttonStyle(.plain)

            Button {
                showCreatorFilterPicker = true
            } label: {
                StatCard(
                    label: "Creators",
                    value: "\(uniqueCreatorCount)",
                    icon: "person.2.fill",
                    color: Constants.Colors.success
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var adminToolGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            NavigationLink {
                AdminApprovalQueueView()
            } label: {
                adminToolCard(
                    title: "Approvals",
                    subtitle: "\(pendingApprovalCount) pending",
                    icon: "clock.badge.checkmark",
                    color: Constants.Colors.success,
                    isSelected: false
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AdminReportsQueueView()
            } label: {
                adminToolCard(
                    title: "Reports",
                    subtitle: "Review flags",
                    icon: "flag.fill",
                    color: Constants.Colors.danger,
                    isSelected: false
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AdminCommentModerationView()
            } label: {
                adminToolCard(
                    title: "Moderate",
                    subtitle: "Comments",
                    icon: "text.bubble.fill",
                    color: Constants.Colors.warning,
                    isSelected: false
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                UserRestrictionManagementView()
            } label: {
                adminToolCard(
                    title: "Restrictions",
                    subtitle: "User controls",
                    icon: "person.crop.circle.badge.exclamationmark",
                    color: Constants.Colors.brandGradientStart,
                    isSelected: false
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func adminToolCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(isSelected ? color.opacity(0.14) : Color(.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? color.opacity(0.4) : .clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var adminEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: mode == .approvalQueue ? "tray" : "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(Constants.Colors.brandGradientStart)
            Text(mode == .approvalQueue ? "No pending approvals" : "No moderation history")
                .font(.headline)
            Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "This section is clear right now."
                : "No events match your search filters.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
    }

    private func approve(_ event: FirestoreEvent) async {
        guard let id = event.id,
              let adminUID = authViewModel.currentUID else { return }
        try? await firestoreManager.approveEvent(id: id, adminUID: adminUID)
    }
}

private enum AdminMode {
    case approvalQueue
    case history
}

// MARK: - Stat Card
private struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [color.opacity(0.13), color.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Admin Event Row
private struct AdminEventRow: View {
    let event: FirestoreEvent
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Constants.CategoryColors.color(for: event.category).opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: Constants.CategoryColors.icon(for: event.category))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Constants.CategoryColors.color(for: event.category))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 9))
                        Text(event.venue)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(event.shortDate)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text("by \(event.creatorEmail)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            CategoryBadgeView(category: event.category, style: .compact)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius))
    }
}
