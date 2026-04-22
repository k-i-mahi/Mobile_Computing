// ============================================================
// EventListView.swift
// Browse events with search, filter, and stagger animations
// ============================================================

import SwiftUI

struct EventListView: View {
    @EnvironmentObject var eventVM: EventJSONViewModel
    @State private var showFilterSheet = false
    @State private var appeared = false

    var body: some View {
        Group {
            if eventVM.isLoading {
                LoadingView(message: "Loading events…")
            } else if let error = eventVM.errorMessage {
                ErrorView(message: error) {
                    eventVM.loadEvents()
                }
            } else {
                mainContent
            }
        }
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $eventVM.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search events, venues, organizers…")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                filterButton
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                sortMenu
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            EventFilterView(
                selectedCategory: $eventVM.selectedCategory,
                categories: eventVM.categories
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
    
    // MARK: - Filter Button
    private var filterButton: some View {
        Button {
            HapticManager.impact(.light)
            showFilterSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: eventVM.selectedCategory == "All"
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill")
                
                if eventVM.selectedCategory != "All" {
                    Text(eventVM.selectedCategory)
                        .font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(eventVM.selectedCategory == "All" ? .primary : Constants.Colors.brandGradientStart)
            .padding(.horizontal, eventVM.selectedCategory == "All" ? 0 : 10)
            .padding(.vertical, eventVM.selectedCategory == "All" ? 0 : 6)
            .background(eventVM.selectedCategory == "All" ? .clear : Constants.Colors.brandGradientStart.opacity(0.1))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: Constants.Design.cardSpacing) {
                if eventVM.filteredEvents.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        title: "No events found",
                        message: "Try adjusting your search or filter to discover more events.",
                        buttonTitle: "Clear Filter",
                        action: { eventVM.clearFilter() }
                    )
                } else {
                    HStack {
                        Text("\(eventVM.filteredEvents.count) event\(eventVM.filteredEvents.count == 1 ? "" : "s")")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, Constants.Design.horizontalPadding)
                    
                    ForEach(Array(eventVM.filteredEvents.enumerated()), id: \.element.id) { index, event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            EventCardView(event: event)
                                .staggeredAppear(index: index, show: appeared)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Constants.Design.horizontalPadding)
            .padding(.vertical, 12)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $eventVM.selectedSortOption) {
                ForEach(Constants.eventSortOptions) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.title3)
                .foregroundStyle(.primary)
        }
    }
}
