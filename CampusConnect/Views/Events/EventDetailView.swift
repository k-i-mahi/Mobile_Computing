// ============================================================
// EventDetailView.swift
// Rich event detail with parallax banner, RSVP, and organizer
// ============================================================

import SwiftUI

struct EventDetailView: View {
    let event: Event
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var seatVM = SeatScoreViewModel(totalSeats: 100, takenSeats: 24)
    @StateObject private var rsvpManager = RSVPManager()
    @State private var showOrganizerSheet = false
    @State private var appeared = false
    
    private var eventId: String { event.id }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                bannerSection
                
                VStack(alignment: .leading, spacing: Constants.Design.sectionSpacing) {
                    infoSection
                    
                    if let desc = event.description, !desc.isEmpty {
                        descriptionSection(desc)
                    }
                    
                    // Tags
                    if let tags = event.tags, !tags.isEmpty {
                        tagsSection(tags)
                    }
                    
                    SeatCounterView(viewModel: seatVM)
                    
                    rsvpSection
                    
                    organizerCard
                }
                .padding(.horizontal, Constants.Design.horizontalPadding)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showOrganizerSheet) {
            OrganizerProfileView(organizer: event.organizer)
        }
        .task {
            if let uid = authViewModel.currentUID {
                await rsvpManager.checkRSVP(eventId: eventId, uid: uid)
                rsvpManager.listenRSVPCount(eventId: eventId)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
    
    // MARK: - Banner
    private var bannerSection: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Constants.CategoryColors.gradient(for: event.category))
                .frame(height: 220)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: Constants.CategoryColors.icon(for: event.category))
                        .font(.system(size: 80))
                        .foregroundStyle(.white.opacity(0.1))
                        .rotationEffect(.degrees(-15))
                        .offset(x: -20, y: 20)
                }
            
            // Gradient overlay for readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)
            
            VStack(alignment: .leading, spacing: 10) {
                CategoryBadgeView(category: event.category, style: .pill)
                
                Text(event.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(3)
                
                if let days = event.daysUntil, days >= 0 {
                    Text(days == 0 ? "Happening Today!" : (days == 1 ? "Tomorrow" : "In \(days) days"))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(spacing: 0) {
            infoRow(icon: "mappin.and.ellipse", label: "Venue", value: event.venue, color: Constants.Colors.danger)
            Divider().padding(.leading, 52)
            infoRow(icon: "calendar", label: "Date", value: event.formattedDate, color: Constants.Colors.brandGradientStart)
            Divider().padding(.leading, 52)
            infoRow(icon: "person.fill", label: "Organizer", value: event.organizerName, color: .purple)
            if let seats = event.seats {
                Divider().padding(.leading, 52)
                infoRow(icon: "chair.fill", label: "Capacity", value: "\(seats) seats", color: Constants.Colors.accent)
            }
        }
        .background(Constants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius, style: .continuous))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }
    
    private func infoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Description
    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("About this Event", systemImage: "text.alignleft")
                .font(.subheadline.weight(.semibold))
            
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Constants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius, style: .continuous))
    }
    
    // MARK: - Tags
    private func tagsSection(_ tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tags", systemImage: "tag.fill")
                .font(.subheadline.weight(.semibold))
            
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Constants.Colors.brandGradientStart.opacity(0.08))
                        .foregroundStyle(Constants.Colors.brandGradientStart)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Constants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius, style: .continuous))
    }
    
    // MARK: - RSVP
    private var rsvpSection: some View {
        let alreadyRSVPed = rsvpManager.isRSVPed(eventId: eventId)
        let canBook = seatVM.canRSVP()
        
        return VStack(spacing: 14) {
            HStack {
                Label("RSVP", systemImage: "person.badge.plus")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(rsvpManager.rsvpCount) registered")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            
            Button {
                HapticManager.impact(.medium)
                Task {
                    guard let uid = authViewModel.currentUID else { return }
                    let email = authViewModel.currentEmail
                    if alreadyRSVPed {
                        await rsvpManager.cancelRSVP(eventId: eventId, uid: uid)
                        seatVM.cancelSeat()
                    } else if canBook.canBook {
                        await rsvpManager.rsvp(eventId: eventId, uid: uid, email: email)
                        seatVM.bookSeat()
                    }
                }
            } label: {
                Label(
                    alreadyRSVPed ? "Cancel RSVP" : (canBook.canBook ? "RSVP to this Event" : "Event Full"),
                    systemImage: alreadyRSVPed ? "xmark.circle.fill" : (canBook.canBook ? "checkmark.circle.fill" : "nosign")
                )
                .frame(maxWidth: .infinity)
                .frame(height: Constants.Design.buttonHeight)
                .background(rsvpButtonBackground(isRSVPed: alreadyRSVPed, canBook: canBook.canBook))
                .foregroundStyle(rsvpButtonForeground(isRSVPed: alreadyRSVPed, canBook: canBook.canBook))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .font(.headline)
            }
            .disabled(!canBook.canBook && !alreadyRSVPed)
            
            if !canBook.canBook && !alreadyRSVPed {
                Text(canBook.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Constants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius, style: .continuous))
    }
    
    private func rsvpButtonBackground(isRSVPed: Bool, canBook: Bool) -> some ShapeStyle {
        if isRSVPed { return AnyShapeStyle(Constants.Colors.danger.opacity(0.12)) }
        if canBook { return AnyShapeStyle(Constants.Colors.brandGradient) }
        return AnyShapeStyle(Color(.systemGray5))
    }
    
    private func rsvpButtonForeground(isRSVPed: Bool, canBook: Bool) -> Color {
        if isRSVPed { return Constants.Colors.danger }
        if canBook { return .white }
        return .secondary
    }
    
    // MARK: - Organizer Card
    private var organizerCard: some View {
        Button {
            HapticManager.impact(.light)
            showOrganizerSheet = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Constants.CategoryColors.color(for: event.category).opacity(0.12))
                        .frame(width: 50, height: 50)
                    Text(event.organizer.initials)
                        .font(.headline.bold())
                        .foregroundStyle(Constants.CategoryColors.color(for: event.category))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.organizerName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(event.organizerRole)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Constants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius, style: .continuous))
        }
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxRowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += maxRowHeight + spacing
                maxRowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            maxRowHeight = max(maxRowHeight, size.height)
            x += size.width + spacing
        }
        
        return (CGSize(width: maxWidth, height: y + maxRowHeight), positions)
    }
}
