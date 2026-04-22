// ============================================================
// EventCardView.swift
// Premium event card with date badge, gradient banner, and tags
// ============================================================

import SwiftUI

struct EventCardView: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner
            bannerSection
            
            // Content
            VStack(alignment: .leading, spacing: 10) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                
                // Venue
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption2)
                    Text(event.venue)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                
                // Bottom row: date + tags/seats
                HStack(spacing: 0) {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(event.shortDate)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Days countdown
                    if let days = event.daysUntil, days >= 0 {
                        Text(days == 0 ? "Today" : (days == 1 ? "Tomorrow" : "in \(days)d"))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Constants.Colors.success.opacity(0.12))
                            .foregroundStyle(Constants.Colors.success)
                            .clipShape(Capsule())
                    }
                    
                    if let seats = event.seats {
                        Text("\(seats) seats")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Constants.Colors.brandGradientStart.opacity(0.1))
                            .foregroundStyle(Constants.Colors.brandGradientStart)
                            .clipShape(Capsule())
                            .padding(.leading, 6)
                    }
                }

                HStack(spacing: 12) {
                    Label("\(event.upvoteCount)", systemImage: "hand.thumbsup.fill")
                        .font(.caption2)
                        .foregroundStyle(Constants.Colors.brandGradientStart)
                    Label("\(event.commentCount)", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.caption2)
                        .foregroundStyle(Constants.Colors.accent)
                    if event.isTrending {
                        Text("Trending")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Constants.Colors.warning.opacity(0.16))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }

                if let discussion = event.discussionLabel {
                    Text(discussion)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if event.status != .approved {
                    Text(event.status.userFacingLabel)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Constants.Colors.warning.opacity(0.14))
                        .foregroundStyle(Constants.Colors.warning)
                        .clipShape(Capsule())
                }
                
                // Tags
                if let tags = event.tags, !tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Constants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cardCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Banner
    private var bannerSection: some View {
        ZStack {
            bannerBackground

            LinearGradient(
                colors: [.clear, .black.opacity(0.28)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack {
                if let dm = event.dayMonth {
                    VStack(spacing: 0) {
                        Text(dm.month)
                            .font(.caption2.weight(.bold))
                        Text(dm.day)
                            .font(.title3.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Spacer()

                CategoryBadgeView(category: event.category, style: .pill)

                Spacer()

                Image(systemName: Constants.CategoryColors.icon(for: event.category))
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(height: 94)
        .cornerRadius(Constants.Design.cardCornerRadius, corners: [.topLeft, .topRight])
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
        } else if let imageName = event.imageName, !imageName.isEmpty {
            Image(imageName)
                .resizable()
                .scaledToFill()
        } else {
            bannerFallback
        }
    }

    private var bannerFallback: some View {
        Constants.CategoryColors.gradient(for: event.category)
    }
}
