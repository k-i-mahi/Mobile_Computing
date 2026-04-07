// ============================================================
// DashboardView.swift
// Main tab-based navigation hub with polished tab bar
// ============================================================

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var eventVM = EventJSONViewModel()
    @State private var selectedTab = 0
    
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
            
            // Tab 3 — News
            NavigationStack {
                NewsListView()
            }
            .tag(2)
            .tabItem {
                Label("News", systemImage: selectedTab == 2 ? "newspaper.fill" : "newspaper")
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
        .onChange(of: selectedTab) { _, _ in
            HapticManager.selection()
        }
    }
}
