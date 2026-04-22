import SwiftUI

struct UpcomingEventsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var manager = FirestoreEventManager()

    private var filtered: [FirestoreEvent] {
        manager.userEvents
            .filter { $0.isUpcoming || [.pendingApproval, .rejected, .approved, .expired, .archived].contains($0.lifecycleStatus) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        Group {
            if manager.isLoading && filtered.isEmpty {
                LoadingView(message: "Loading upcoming events...")
            } else if filtered.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.exclamationmark",
                    title: "No Upcoming Events",
                    message: "Events you create will appear here with their review status.",
                    buttonTitle: nil,
                    action: nil
                )
            } else {
                List {
                    ForEach(filtered, id: \.id) { event in
                        row(event)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Upcoming Events")
        .task {
            if let uid = authViewModel.currentUID {
                manager.startListening(uid: uid)
            }
        }
        .onDisappear {
            manager.stopListening()
        }
    }

    @ViewBuilder
    private func row(_ event: FirestoreEvent) -> some View {
        if event.lifecycleStatus == .rejected {
            NavigationLink {
                RejectionFeedbackDetailView(event: event)
            } label: {
                eventRowBody(event)
            }
        } else {
            NavigationLink {
                EventDetailView(event: event.asEvent)
            } label: {
                eventRowBody(event)
            }
        }
    }

    private func eventRowBody(_ event: FirestoreEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(event.lifecycleStatus.userFacingLabel)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Constants.Colors.warning.opacity(0.12))
                    .clipShape(Capsule())
            }
            HStack(spacing: 8) {
                Label(event.shortDate, systemImage: "calendar")
                Label(event.venue, systemImage: "mappin.and.ellipse")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let reason = event.rejectionReason, !reason.isEmpty {
                Text("Feedback: \(reason)")
                    .font(.caption)
                    .foregroundStyle(Constants.Colors.danger)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
