// ============================================================
// MyEventsView.swift
// Shows the user's own Firestore events with edit / delete
// ============================================================

import SwiftUI

struct MyEventsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var manager = FirestoreEventManager()
    @State private var editingEvent: FirestoreEvent?
    @State private var showDeleteConfirm = false
    @State private var eventToDelete: FirestoreEvent?
    @State private var appeared = false
    @State private var selectedSection: MyEventsSection = .upcoming

    private var upcomingUserEvents: [FirestoreEvent] {
        manager.userEvents.filter { $0.isUpcoming }
    }

    private var canCreateEvent: Bool {
        authViewModel.accountStatus != .eventRestricted && authViewModel.accountStatus != .banned
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedSection) {
                ForEach(MyEventsSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Group {
                switch selectedSection {
                case .noticeBoard:
                    NoticeBoardView()
                case .createEvent:
                    if canCreateEvent {
                        NavigationLink {
                            CreateEventView()
                        } label: {
                            EmptyStateView(
                                icon: "plus.circle.fill",
                                title: "Create Campus Event",
                                message: "Submit your event for admin approval.",
                                buttonTitle: "Open Event Form",
                                action: nil
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        EmptyStateView(
                            icon: "exclamationmark.shield.fill",
                            title: "Event Creation Restricted",
                            message: "Your account is currently restricted from creating events. Contact campus admin for details.",
                            buttonTitle: nil,
                            action: nil
                        )
                    }
                case .upcoming:
                    UpcomingEventsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("My Events")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if canCreateEvent {
                    NavigationLink {
                        CreateEventView()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.title3)
                            .foregroundStyle(Constants.Colors.brandGradientStart)
                    }
                }
            }
            ToolbarItem(placement: .status) {
                if !manager.userEvents.isEmpty {
                    Text("\(manager.userEvents.count) event\(manager.userEvents.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            if let uid = authViewModel.currentUID {
                manager.startListening(uid: uid)
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) { appeared = true }
        }
        .onDisappear { manager.stopListening() }
        .sheet(item: $editingEvent) { event in
            EditEventView(event: event)
        }
        .confirmationDialog("Delete Event", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let e = eventToDelete {
                    Task { await deleteEvent(e) }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .overlay {
            if let msg = manager.errorMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Constants.Colors.danger.gradient, in: Capsule())
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4), value: msg)
            }
        }
    }

    @ViewBuilder
    private func contentList(_ events: [FirestoreEvent]) -> some View {
        if manager.isLoading && events.isEmpty {
            LoadingView(message: "Loading your events…")
        } else if events.isEmpty {
            EmptyStateView(
                icon: "calendar.badge.plus",
                title: "No Upcoming Events",
                message: "Create your first event and start organizing something awesome on campus.",
                buttonTitle: nil,
                action: nil
            )
        } else {
            List {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    MyEventRow(event: event)
                        .staggeredAppear(index: index, show: appeared)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                eventToDelete = event
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingEvent = event
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Constants.Colors.brandGradientStart)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        }
    }

    private func deleteEvent(_ event: FirestoreEvent) async {
        do {
            try await manager.deleteEvent(event)
            HapticManager.notification(.success)
        } catch {
            HapticManager.notification(.error)
        }
    }
}

private enum MyEventsSection: String, CaseIterable, Identifiable {
    case noticeBoard = "Notice Board"
    case createEvent = "Create Event"
    case upcoming = "Upcoming Events"

    var id: String { rawValue }
}

// MARK: – My Event Row
private struct MyEventRow: View {
    let event: FirestoreEvent

    var body: some View {
        HStack(spacing: 14) {
            // Date badge
            VStack(spacing: 2) {
                Text(event.dayMonth.day)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Constants.Colors.brandGradientStart)
                Text(event.dayMonth.month)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .frame(width: 48, height: 54)
            .background(Constants.Colors.brandGradientStart.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text(event.venue)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                CategoryBadgeView(category: event.category, style: .compact)

                Text(event.lifecycleStatus.userFacingLabel)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Constants.Colors.warning.opacity(0.15))
                    .foregroundStyle(Constants.Colors.warning)
                    .clipShape(Capsule())
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius))
    }
}
