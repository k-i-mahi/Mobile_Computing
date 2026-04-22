// ============================================================
// EventDetailView.swift
// Rich event detail with parallax banner, interactions, and organizer
// ============================================================

import SwiftUI
import FirebaseFirestore
import UIKit

struct EventDetailView: View {
    let event: Event
    let focusCommentId: String?
    let focusReplyId: String?
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var firestoreManager = FirestoreEventManager()
    @StateObject private var notificationsVM = NotificationsViewModel()
    @State private var showOrganizerSheet = false
    @State private var appeared = false
    @State private var hasUpvoted = false
    @State private var eventNotificationOn = false
    @State private var showReportSheet = false
    @State private var reminderOffsetHours = 24
    @State private var liveUpvoteCount: Int
    @State private var liveCommentCount: Int
    @State private var eventStatsListener: ListenerRegistration?
    @State private var upvoteStateListener: ListenerRegistration?
    @State private var isUpvoteUpdating = false
    @State private var showAllUserRadioSelected = false
    @State private var showUpvoteUsersSheet = false

    private var isCompactWidth: Bool {
        UIScreen.main.bounds.width < 390
    }

    private var actionGridColumns: [GridItem] {
        if isCompactWidth {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    init(event: Event, focusCommentId: String? = nil, focusReplyId: String? = nil)
    {
        self.event=event
        self.focusCommentId = focusCommentId
        self.focusReplyId = focusReplyId
        _liveUpvoteCount = State(initialValue: event.upvoteCount)
        _liveCommentCount = State(initialValue: event.commentCount)
    }

    private var eventId: String { event.id }

    private var canReportEvent: Bool {
        guard let uid = authViewModel.currentUID else { return false }
        return event.creatorUid != uid
    }

    private var canToggleEventNotifications: Bool {
        guard let eventDate = DateFormatterHelper.date(from: event.date) else { return true }
        let expiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: eventDate)) ?? eventDate
        return expiresAt > Date()
    }
    
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

                    interestMomentumSection

                    interactionDockSection

                    CommentsSectionView(eventId: eventId, focusCommentId: focusCommentId, focusReplyId: focusReplyId)
                    
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
        .sheet(isPresented: $showUpvoteUsersSheet, onDismiss: {
            showAllUserRadioSelected = false
        }) {
            NavigationStack {
                UpvoteViewerView(eventId: eventId, eventTitle: event.title)
            }
        }
        .alert("Notification Permission Denied", isPresented: $notificationsVM.permissionDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your event preference was saved in CampusConnect. Enable notifications from iOS Settings to receive device alerts.")
        }
        .confirmationDialog("Report", isPresented: $showReportSheet, titleVisibility: .visible) {
            ForEach(Constants.reportCategories, id: \.self) { reason in
                Button(reason) {
                    Task {
                        guard let uid = authViewModel.currentUID else { return }
                        await firestoreManager.reportEvent(
                            eventId: eventId,
                            reporterUid: uid,
                            reason: reason,
                            description: "Submitted from Event Details"
                        )
                    }
                }
            }
        } message: {
            Text("Your report will be sent to moderators for manual review.")
        }
        .task {
            if let uid = authViewModel.currentUID {
                hasUpvoted = await firestoreManager.hasUpvoted(eventId: eventId, uid: uid)

                upvoteStateListener?.remove()
                upvoteStateListener = Firestore.firestore()
                    .collection("events").document(eventId)
                    .collection("upvotes").document(uid)
                    .addSnapshotListener { snapshot, _ in
                        hasUpvoted = snapshot?.exists == true
                    }

                let reminderSnapshot = try? await Firestore.firestore()
                    .collection("user_event_reminders")
                    .document(uid)
                    .collection("items")
                    .document(eventId)
                    .getDocument()
                let reminderData = reminderSnapshot?.data()
                eventNotificationOn = reminderData?["isEnabled"] as? Bool ?? false
                reminderOffsetHours = reminderData?["reminderOffsetHours"] as? Int ?? reminderOffsetHours
            }

            eventStatsListener?.remove()
            eventStatsListener = Firestore.firestore().collection("events").document(eventId)
                .addSnapshotListener { snapshot, _ in
                    guard let data = snapshot?.data() else { return }
                    if let upvotes = data["upvoteCount"] as? Int {
                        liveUpvoteCount = upvotes
                    }
                    if let comments = data["commentCount"] as? Int {
                        liveCommentCount = comments
                    }
                }
        }
        .onDisappear {
            eventStatsListener?.remove()
            eventStatsListener = nil
            upvoteStateListener?.remove()
            upvoteStateListener = nil
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    // MARK: - Interest Snapshot
    private var interestMomentumSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(Constants.Colors.warning)
                Text("Live Interest")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("\(formatCompactCount(liveUpvoteCount)) people are interested in this event!")
                .font(isCompactWidth ? .headline.weight(.bold) : .title3.weight(.bold))
                .foregroundStyle(.primary)

            Text("\(formatCompactCount(liveCommentCount)) comments in active discussion")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Constants.Colors.brandGradientStart.opacity(0.08),
                    Constants.Colors.accent.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius, style: .continuous)
                .stroke(Constants.Colors.brandGradientStart.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius, style: .continuous))
    }

    // MARK: - Social Actions
    private var interactionDockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Interact")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Realtime")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: actionGridColumns, spacing: 10) {
                actionTile(
                    title: hasUpvoted ? "Upvoted" : "Upvote",
                    subtitle: "\(formatCompactCount(liveUpvoteCount)) interested",
                    icon: hasUpvoted ? "hand.thumbsup.fill" : "hand.thumbsup",
                    tint: hasUpvoted ? Constants.Colors.brandGradientStart : .secondary,
                    background: hasUpvoted ? Constants.Colors.brandGradientStart.opacity(0.16) : Color.secondary.opacity(0.1),
                    disabled: isUpvoteUpdating
                ) {
                    Task {
                        guard let uid = authViewModel.currentUID, !isUpvoteUpdating else { return }
                        isUpvoteUpdating = true
                        do {
                            try await firestoreManager.toggleUpvote(eventId: eventId, uid: uid)
                            HapticManager.selection()
                        } catch {
                            HapticManager.notification(.error)
                        }
                        isUpvoteUpdating = false
                    }
                }

                actionTile(
                    title: canToggleEventNotifications ? (eventNotificationOn ? "Notifying" : "Turn On") : "Expired",
                    subtitle: canToggleEventNotifications ? (eventNotificationOn ? "For this event" : "Notifications for this event") : "Notifications closed",
                    icon: eventNotificationOn ? "bell.fill" : "bell",
                    tint: Constants.Colors.accent,
                    background: Constants.Colors.accent.opacity(0.14),
                    disabled: !canToggleEventNotifications
                ) {
                    Task {
                        let nextState = !eventNotificationOn
                        guard let uid = authViewModel.currentUID else { return }
                        let eventDate = DateFormatterHelper.date(from: event.date) ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        let didSave = await notificationsVM.setReminder(
                            uid: uid,
                            eventId: event.id,
                            eventTitle: event.title,
                            eventDate: eventDate,
                            enabled: nextState,
                            offsetHours: reminderOffsetHours
                        )
                        if didSave {
                            eventNotificationOn = nextState
                        }
                    }
                }

                ShareLink(item: "campusconnect://event/\(event.id)") {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Send link")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                actionTile(
                    title: "Report",
                    subtitle: "Needs review",
                    icon: "flag.fill",
                    tint: Constants.Colors.danger,
                    background: Constants.Colors.danger.opacity(0.12),
                    disabled: !canReportEvent,
                    blurWhenDisabled: true
                ) {
                    if canReportEvent {
                        showReportSheet = true
                    }
                }
            }

            if authViewModel.role == .admin {
                Button {
                    let nextState = !showAllUserRadioSelected
                    showAllUserRadioSelected = nextState
                    if nextState {
                        showUpvoteUsersSheet = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: showAllUserRadioSelected ? "largecircle.fill.circle" : "circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Constants.Colors.brandGradientStart)
                        Text("show all user")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("Reminder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("1 hour before") { reminderOffsetHours = 1 }
                    Button("3 hours before") { reminderOffsetHours = 3 }
                    Button("6 hours before") { reminderOffsetHours = 6 }
                    Button("12 hours before") { reminderOffsetHours = 12 }
                    Button("1 day before") { reminderOffsetHours = 24 }
                    Button("2 days before") { reminderOffsetHours = 48 }
                } label: {
                    Text(reminderOffsetLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(18)
        .background(Constants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func actionTile(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        background: Color,
        disabled: Bool = false,
        blurWhenDisabled: Bool = false,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity((disabled && blurWhenDisabled) ? 0.45 : 1)
        .blur(radius: (disabled && blurWhenDisabled) ? 0.7 : 0)
    }

    private func formatCompactCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fm", Double(value) / 1_000_000.0)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000.0)
        }
        return "\(value)"
    }

    private var reminderOffsetLabel: String {
        if reminderOffsetHours < 24 {
            return "\(reminderOffsetHours)h before"
        }
        let days = reminderOffsetHours / 24
        return days == 1 ? "1 day before" : "\(days) days before"
    }
    
    // MARK: - Banner
    private var bannerSection: some View {
        ZStack(alignment: .bottomLeading) {
            bannerBackground
                .frame(height: 220)
            
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

    @ViewBuilder
    private var bannerBackground: some View {
        if let imageURL = event.imageURL,
           let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    bannerFallback
                }
            }
            .clipped()
        } else if let imageName = event.imageName, !imageName.isEmpty {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            bannerFallback
        }
    }

    private var bannerFallback: some View {
        Constants.CategoryColors.gradient(for: event.category)
            .overlay(alignment: .topTrailing) {
                Image(systemName: Constants.CategoryColors.icon(for: event.category))
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.1))
                    .rotationEffect(.degrees(-15))
                    .offset(x: -20, y: 20)
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
