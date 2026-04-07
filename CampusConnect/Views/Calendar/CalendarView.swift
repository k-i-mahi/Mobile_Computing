// ============================================================
// CalendarView.swift
// Events grouped by date with section headers
// ============================================================

import SwiftUI

struct CalendarView: View {
    @ObservedObject var eventVM: EventJSONViewModel
    @State private var appeared = false
    
    /// Events grouped by their date string, sorted ascending
    private var eventsByDate: [(date: String, events: [Event])] {
        let grouped = Dictionary(grouping: eventVM.filteredEvents) { $0.date }
        return grouped
            .map { (date: $0.key, events: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if eventsByDate.isEmpty {
                    EmptyStateView(
                        icon: "calendar",
                        title: "No Upcoming Events",
                        message: "There are no events matching the current filters.",
                        buttonTitle: nil,
                        action: nil
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                            ForEach(Array(eventsByDate.enumerated()), id: \.element.date) { sectionIdx, section in
                                Section {
                                    ForEach(Array(section.events.enumerated()), id: \.element.id) { idx, event in
                                        NavigationLink {
                                            EventDetailView(event: event)
                                        } label: {
                                            CalendarEventRow(event: event)
                                                .staggeredAppear(index: sectionIdx * 3 + idx, show: appeared)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } header: {
                                    DateSectionHeader(dateString: section.date, count: section.events.count)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Calendar")
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) { appeared = true }
            }
        }
    }
}

// MARK: – Date Section Header
private struct DateSectionHeader: View {
    let dateString: String
    let count: Int
    
    private var parsed: (day: String, month: String, weekday: String)? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dateString) else { return nil }
        let day = DateFormatter()
        day.dateFormat = "d"
        let month = DateFormatter()
        month.dateFormat = "MMM"
        let weekday = DateFormatter()
        weekday.dateFormat = "EEEE"
        return (day.string(from: date), month.string(from: date), weekday.string(from: date))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let p = parsed {
                VStack(spacing: 0) {
                    Text(p.day)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Constants.Colors.brandGradientStart)
                    Text(p.month)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                .frame(width: 44, height: 44)
                .background(Constants.Colors.brandGradientStart.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.weekday)
                        .font(.subheadline.weight(.semibold))
                    Text("\(count) event\(count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(dateString)
                    .font(.subheadline.weight(.semibold))
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(.bar)
    }
}

// MARK: – Calendar Event Row
private struct CalendarEventRow: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                Circle()
                    .fill(Constants.CategoryColors.color(for: event.category).opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: Constants.CategoryColors.icon(for: event.category))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Constants.CategoryColors.color(for: event.category))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 9))
                    Text(event.venue)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
            
            VStack(alignment: .trailing, spacing: 4) {
                if event.isUpcoming {
                    Text("Upcoming")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Constants.Colors.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Constants.Colors.success.opacity(0.12), in: Capsule())
                }
                if let seats = event.seatLabel {
                    Text(seats)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius))
    }
}
