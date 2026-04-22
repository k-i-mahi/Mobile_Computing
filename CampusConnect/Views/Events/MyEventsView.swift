// ============================================================
// MyEventsView.swift
// Lists events created by the current user with edit/delete
// ============================================================

import SwiftUI

struct MyEventsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var firestoreManager: FirestoreEventManager
    @State private var showCreateSheet = false
    @State private var eventToEdit: FirestoreEvent?
    @State private var deleteError: String?

    var body: some View {
        Group {
            if firestoreManager.myEvents.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "No events yet",
                    message: "Events you create will appear here.",
                    buttonTitle: "Create Event",
                    action: { showCreateSheet = true }
                )
            } else {
                eventList
            }
        }
        .navigationTitle("My Events")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Constants.Colors.brandGradientStart)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateEventView()
        }
        .sheet(item: $eventToEdit) { event in
            EditEventView(event: event)
        }
        .alert("Error", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
        .task {
            if let uid = authViewModel.currentUID {
                firestoreManager.startListeningMyEvents(uid: uid)
            }
        }
    }

    private var eventList: some View {
        List {
            ForEach(firestoreManager.myEvents) { event in
                NavigationLink(destination: EventDetailView(event: event.asEvent)) {
                    MyEventRowView(event: event)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task {
                            guard let id = event.id else { return }
                            do {
                                try await firestoreManager.deleteEvent(id: id)
                            } catch {
                                deleteError = error.localizedDescription
                            }
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        eventToEdit = event
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(Constants.Colors.brandGradientStart)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Row

struct MyEventRowView: View {
    let event: FirestoreEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                statusBadge(event.status)
            }
            Label(event.date.dateValue().formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                status == "approved" ? Color.green.opacity(0.15) :
                status == "rejected" ? Color.red.opacity(0.12) :
                Color.orange.opacity(0.15)
            )
            .foregroundStyle(
                status == "approved" ? Color.green :
                status == "rejected" ? Color.red :
                Color.orange
            )
            .clipShape(Capsule())
    }
}
