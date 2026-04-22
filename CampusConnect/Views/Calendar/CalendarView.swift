// ============================================================
// CalendarView.swift
// Desk-style month calendar with day markers and selected-day events
// ============================================================

import SwiftUI
import FirebaseFirestore

struct CalendarView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var eventVM: EventJSONViewModel
    @StateObject private var firestoreManager = FirestoreEventManager()
    @State private var monthOffset = 0
    @State private var upvotedEventIDs: Set<String> = []
    @State private var reminderEnabledEventIDs: Set<String> = []
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    
    private var calendar: Calendar { .current }

    private var currentMonthDate: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonthDate)
    }

    private var daysInMonth: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: currentMonthDate),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: interval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: interval.end.addingTimeInterval(-1)) else {
            return []
        }

        var days: [Date] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            days.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        return days
    }

    private var selectedDayEvents: [Event] {
        eventVM.allEvents
            .filter { event in
                guard let eventDate = DateFormatterHelper.date(from: event.date) else { return false }
                return calendar.isDate(eventDate, inSameDayAs: selectedDate)
            }
            .sorted {
                let lhs = DateFormatterHelper.date(from: $0.date) ?? .distantFuture
                let rhs = DateFormatterHelper.date(from: $1.date) ?? .distantFuture
                return lhs < rhs
            }
    }

    private func events(for day: Date) -> [Event] {
        eventVM.allEvents.filter { event in
            guard let eventDate = DateFormatterHelper.date(from: event.date) else { return false }
            return calendar.isDate(eventDate, inSameDayAs: day)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdaysHeader
            calendarLegend
            monthGrid

            if selectedDayEvents.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "No Events on This Day",
                    message: "Tap a marked day to see your campus events.",
                    buttonTitle: nil,
                    action: nil
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(selectedDayEvents, id: \.id) { event in
                            NavigationLink {
                                EventDetailView(event: event)
                            } label: {
                                CalendarEventRow(event: event, isUpvoted: upvotedEventIDs.contains(event.id))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.top, 8)
        .navigationTitle("Calendar")
        .task(id: "\(authViewModel.currentUID ?? "")::\(eventVM.allEvents.map(\.id).joined(separator: ","))") {
            await loadPersonalizedCalendarState()
        }
    }

    private var calendarLegend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Constants.Colors.brandGradientStart)
                    .frame(width: 6, height: 6)
                Text("Upvoted")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(Constants.Colors.accent)
                    .frame(width: 6, height: 6)
                Text("Notifications On")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                monthOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()
            Text(monthTitle)
                .font(.headline.weight(.bold))
            Spacer()

            Button {
                monthOffset += 1
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal, 16)
    }

    private var weekdaysHeader: some View {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        return HStack {
            ForEach(symbols, id: \.self) { day in
                Text(day)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(daysInMonth, id: \.self) { day in
                let isCurrentMonth = calendar.isDate(day, equalTo: currentMonthDate, toGranularity: .month)
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                let dayEvents = events(for: day)
                let hasUpvoted = dayEvents.contains { upvotedEventIDs.contains($0.id) }
                let hasReminderOn = dayEvents.contains { reminderEnabledEventIDs.contains($0.id) }

                Button {
                    selectedDate = calendar.startOfDay(for: day)
                } label: {
                    VStack(spacing: 4) {
                        Text("\(calendar.component(.day, from: day))")
                            .font(.caption.weight(isSelected ? .bold : .regular))
                            .foregroundStyle(isCurrentMonth ? (isSelected ? .white : .primary) : .secondary)

                        HStack(spacing: 3) {
                            Circle()
                                .fill(hasUpvoted ? Constants.Colors.brandGradientStart : .clear)
                                .frame(width: 5, height: 5)
                            Circle()
                                .fill(hasReminderOn ? Constants.Colors.accent : .clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(isSelected ? Constants.Colors.brandGradientStart : Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func loadPersonalizedCalendarState() async {
        guard let uid = authViewModel.currentUID else {
            upvotedEventIDs = []
            reminderEnabledEventIDs = []
            return
        }

        async let upvoted = firestoreManager.fetchUpvotedEventIDs(uid: uid, eventIDs: eventVM.allEvents.map(\.id))
        async let reminders = fetchEnabledReminderEventIDs(uid: uid)

        upvotedEventIDs = await upvoted
        reminderEnabledEventIDs = await reminders
    }

    private func fetchEnabledReminderEventIDs(uid: String) async -> Set<String> {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("user_event_reminders")
                .document(uid)
                .collection("items")
                .whereField("isEnabled", isEqualTo: true)
                .getDocuments()

            return Set(snapshot.documents.compactMap { doc in
                (doc.data()["eventId"] as? String) ?? doc.documentID
            })
        } catch {
            return []
        }
    }
}

// MARK: – Calendar Event Row
private struct CalendarEventRow: View {
    let event: Event
    let isUpvoted: Bool
    
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
                if isUpvoted {
                    Text("Upvoted")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Constants.Colors.brandGradientStart)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Constants.Colors.brandGradientStart.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius))
    }
}
