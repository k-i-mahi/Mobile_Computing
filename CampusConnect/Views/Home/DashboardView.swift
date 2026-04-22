// ============================================================
// DashboardView.swift
// Main tab-based navigation hub with polished tab bar
// ============================================================

import SwiftUI
import FirebaseFirestore

struct DashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @EnvironmentObject var notificationsVM: NotificationsViewModel
    @StateObject private var eventVM = EventJSONViewModel()
    @StateObject private var firestoreManager = FirestoreEventManager()
    @StateObject private var profileVM = ProfileViewModel()
    @State private var selectedTab = 0
    @State private var deepLinkedEvent: Event?
    @State private var deepLinkedCommentId: String?
    @State private var deepLinkedReplyId: String?
    @State private var deepLinkErrorMessage: String?

    private var restrictionMessage: String? {
        switch authViewModel.accountStatus {
        case .commentRestricted:
            return "Your account is temporarily restricted from posting comments and replies."
        case .eventRestricted:
            return "Your account is temporarily restricted from creating new events."
        default:
            return nil
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1 — Browse Events
            NavigationStack {
                EventListView()
            }
            .tag(0)
            .tabItem {
                Label("Explore", systemImage: selectedTab == 0 ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack")
            }
            
            // Tab 2 — My Events
            NavigationStack {
                MyEventsView()
            }
            .tag(1)
            .tabItem {
                Label("My Events", systemImage: selectedTab == 1 ? "bookmark.fill" : "bookmark")
            }
            
            // Tab 3 — Notifications
            NavigationStack {
                NotificationsView()
            }
            .tag(2)
            .tabItem {
                Label("Notifications", systemImage: selectedTab == 2 ? "bell.badge.fill" : "bell.badge")
            }
            
            // Tab 4 — Calendar
            NavigationStack {
                CalendarView(eventVM: eventVM)
            }
            .tag(3)
            .tabItem {
                Label("Calendar", systemImage: selectedTab == 3 ? "calendar.circle.fill" : "calendar.circle")
            }
            
            // Tab 5 — Profile
            NavigationStack {
                ProfileView()
            }
            .tag(4)
            .tabItem {
                Label("Profile", systemImage: selectedTab == 4 ? "person.crop.circle.fill" : "person.crop.circle")
            }

        }
        .tint(Constants.Colors.brandGradientStart)
        .environmentObject(eventVM)
        .environmentObject(firestoreManager)
        .safeAreaInset(edge: .top) {
            if let restrictionMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                    Text(restrictionMessage)
                        .lineLimit(2)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Constants.Colors.warning)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Constants.Colors.warning.opacity(0.12))
            }
        }
        .sheet(item: $deepLinkedEvent) { event in
            NavigationStack {
                EventDetailView(event: event, focusCommentId: deepLinkedCommentId, focusReplyId: deepLinkedReplyId)
            }
        }
        .alert("Cannot Open Link", isPresented: Binding(
            get: { deepLinkErrorMessage != nil },
            set: { if !$0 { deepLinkErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deepLinkErrorMessage ?? "Access denied.")
        }
        .onChange(of: selectedTab) { _, _ in
            HapticManager.selection()
        }
        .task {
            eventVM.clearEvents()

            // Load user profile to check admin role
            if let uid = authViewModel.currentUID {
                await profileVM.loadProfile(uid: uid, email: authViewModel.currentEmail)
                notificationsVM.start(uid: uid, email: authViewModel.currentEmail)
            }
            
            // Start listening to ALL events from Firestore
            firestoreManager.startListeningAllEvents(uid: authViewModel.currentUID)
        }
        .onChange(of: firestoreManager.allEvents) { _, newEvents in
            eventVM.setEvents(newEvents.map { $0.asEvent })
        }
        .onChange(of: firestoreManager.errorMessage) { _, newError in
            eventVM.errorMessage = newError
            eventVM.isLoading = false
        }
        .onChange(of: authViewModel.currentUID) { _, _ in
            eventVM.clearEvents()
            firestoreManager.startListeningAllEvents(uid: authViewModel.currentUID)
            if let uid = authViewModel.currentUID {
                notificationsVM.start(uid: uid, email: authViewModel.currentEmail)
            } else {
                notificationsVM.stop()
            }
        }
        .onChange(of: deepLinkManager.pendingEventId) { _, eventId in
            guard let eventId else { return }

            guard authViewModel.isSignedIn else {
                deepLinkErrorMessage = "Please sign in with your campus account to open this event."
                deepLinkManager.clear()
                return
            }

            guard ValidationService.isValidCampusEmail(authViewModel.currentEmail) else {
                deepLinkErrorMessage = "Only campus users can open shared event links."
                deepLinkManager.clear()
                return
            }

            selectedTab = 0
            let commentId = deepLinkManager.pendingCommentId
            let replyId = deepLinkManager.pendingReplyId
            Task {
                await openDeepLinkedEvent(eventId: eventId, commentId: commentId, replyId: replyId)
            }
            deepLinkManager.clear()
        }
        .onChange(of: deepLinkedEvent) { _, value in
            if value == nil {
                deepLinkedCommentId = nil
                deepLinkedReplyId = nil
            }
        }
    }

    @MainActor
    private func openDeepLinkedEvent(eventId: String, commentId: String?, replyId: String?) async {
        deepLinkedCommentId = commentId
        deepLinkedReplyId = replyId

        if let event = eventVM.allEvents.first(where: { $0.id == eventId }) {
            deepLinkedEvent = event
            return
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("events")
                .document(eventId)
                .getDocument()

            guard let event = try? snapshot.data(as: FirestoreEvent.self) else {
                throw FirestoreError.missingID
            }
            deepLinkedEvent = event.asEvent
        } catch {
            deepLinkErrorMessage = "This event is not available or may no longer be public."
            deepLinkedCommentId = nil
            deepLinkedReplyId = nil
        }
    }
}
