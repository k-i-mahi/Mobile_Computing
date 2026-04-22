// ============================================================
// EventDetailView.swift
// Full event detail with RSVP, seat counter, and deep-link support
// ============================================================

import SwiftUI
import FirebaseFirestore

struct EventDetailView: View {
    let event: Event
    var focusCommentId: String? = nil
    var focusReplyId: String?   = nil

    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var rsvpManager = RSVPManager()
    @StateObject private var seatVM      = SeatScoreViewModel()
    @State private var showShareSheet = false
    @State private var rsvpError: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerImage
                contentSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { shareButton }
        .onAppear {
            if let uid = authViewModel.currentUID {
                rsvpManager.startListening(uid: uid)
            }
            seatVM.startTracking(eventId: event.id)
        }
        .onDisappear {
            rsvpManager.stopListening()
            seatVM.stopTracking(eventId: event.id)
        }
        .alert("RSVP Error", isPresented: Binding(
            get: { rsvpError != nil },
            set: { if !$0 { rsvpError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rsvpError ?? "")
        }
    }

    // MARK: - Header

    private var headerImage: some View {
        ZStack(alignment: .bottomLeading) {
            Constants.Colors.brandGradient
                .frame(height: 220)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                CategoryBadgeView(category: event.category, style: .pill)
                Text(event.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(16)
        }
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            metaRow
            Divider()
            descriptionSection
            Divider()
            rsvpSection
        }
        .padding(16)
    }

    private var metaRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(event.venue, systemImage: "mappin.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(event.date.formatted(date: .long, time: .shortened), systemImage: "calendar")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label("Organized by \(event.organizerName)", systemImage: "person.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
            Text(event.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }

    private var rsvpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let level = seatVM.seatScore(for: event.id)
            let info  = seatVM.seatData[event.id]

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Seats")
                        .font(.headline)
                    if let info, info.max > 0 {
                        Text("\(info.remaining) of \(info.max) remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(level.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(level.color == "green" ? .systemGreen : level.color == "red" ? .systemRed : .systemOrange))
                    .clipShape(Capsule())
            }

            let isRSVPed = rsvpManager.isRSVPed(eventId: event.id)
            let isFull   = seatVM.seatData[event.id]?.availabilityLevel == .full && !isRSVPed

            Button {
                Task {
                    guard let uid = authViewModel.currentUID else { return }
                    do {
                        try await rsvpManager.toggleRSVP(event: event, uid: uid)
                    } catch {
                        rsvpError = error.localizedDescription
                    }
                }
            } label: {
                HStack {
                    Image(systemName: isRSVPed ? "checkmark.circle.fill" : "plus.circle.fill")
                    Text(isRSVPed ? "Cancel RSVP" : "RSVP Now")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isRSVPed ? Color.gray.opacity(0.2) : Constants.Colors.brandGradientStart)
                .foregroundStyle(isRSVPed ? .secondary : .white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(rsvpManager.isProcessing || isFull)
        }
    }

    // MARK: - Share

    private var shareButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}
