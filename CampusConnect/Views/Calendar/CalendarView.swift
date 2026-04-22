// ============================================================
// CalendarView.swift
// Monthly calendar with event markers and date navigation
// ============================================================

import SwiftUI

struct CalendarView: View {
    @ObservedObject var eventVM: EventJSONViewModel
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date? = nil

    private let calendar = Calendar.current
    private let columns  = Array(repeating: GridItem(.flexible()), count: 7)
    private let daySymbols = Calendar.current.veryShortWeekdaySymbols

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayRow
            daysGrid
            Divider().padding(.top, 4)
            selectedDateEvents
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation { displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth }
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                    .foregroundStyle(Constants.Colors.brandGradientStart)
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                .font(.headline)
            Spacer()
            Button {
                withAnimation { displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth }
            } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
                    .foregroundStyle(Constants.Colors.brandGradientStart)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Weekday row

    private var weekdayRow: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(daySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Days Grid

    private var daysGrid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(daysInMonth(), id: \.self) { date in
                if let date {
                    DayCellView(
                        date: date,
                        isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                        isToday: calendar.isDateInToday(date),
                        hasEvent: eventsOnDate(date).isEmpty == false
                    )
                    .onTapGesture {
                        HapticManager.impact(.light)
                        selectedDate = date
                    }
                } else {
                    Color.clear
                        .frame(height: 36)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Selected Date Events

    private var selectedDateEvents: some View {
        Group {
            if let date = selectedDate {
                let events = eventsOnDate(date)
                VStack(alignment: .leading, spacing: 8) {
                    Text(date.formatted(date: .long, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    if events.isEmpty {
                        Text("No events on this day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    } else {
                        List(events) { event in
                            NavigationLink(destination: EventDetailView(event: event)) {
                                Text(event.title)
                                    .font(.subheadline)
                            }
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 200)
                    }
                }
            } else {
                Text("Select a day to see events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }
        let firstWeekday = (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7
        let blanks: [Date?] = Array(repeating: nil, count: firstWeekday)
        let days: [Date?] = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
        return blanks + days
    }

    private func eventsOnDate(_ date: Date) -> [Event] {
        eventVM.allEvents.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

// MARK: - Day Cell

struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvent: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.subheadline.weight(isToday || isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : isToday ? Constants.Colors.brandGradientStart : .primary)
                .frame(width: 32, height: 32)
                .background(
                    Group {
                        if isSelected {
                            Constants.Colors.brandGradientStart
                        } else if isToday {
                            Constants.Colors.brandGradientStart.opacity(0.15)
                        } else {
                            Color.clear
                        }
                    }
                )
                .clipShape(Circle())

            if hasEvent {
                Circle()
                    .fill(isSelected ? .white : Constants.Colors.brandGradientStart)
                    .frame(width: 5, height: 5)
            } else {
                Spacer().frame(height: 5)
            }
        }
        .frame(height: 44)
    }
}
