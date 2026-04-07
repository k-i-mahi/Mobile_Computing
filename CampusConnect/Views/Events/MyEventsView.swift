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

    var body: some View {
        Group {
            if manager.isLoading && manager.userEvents.isEmpty {
                LoadingView(message: "Loading your events…")
            } else if manager.userEvents.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "No Events Yet",
                    message: "Create your first event and start organizing something awesome on campus.",
                    buttonTitle: nil,
                    action: nil
                )
            } else {
                List {
                    ForEach(Array(manager.userEvents.enumerated()), id: \.element.id) { index, event in
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
        .navigationTitle("My Events")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CreateEventView()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                        .foregroundStyle(Constants.Colors.brandGradientStart)
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

    private func deleteEvent(_ event: FirestoreEvent) async {
        do {
            try await manager.deleteEvent(event)
            HapticManager.notification(.success)
        } catch {
            HapticManager.notification(.error)
        }
    }
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
