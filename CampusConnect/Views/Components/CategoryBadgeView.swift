// ============================================================
// CategoryBadgeView.swift
// Reusable category badge with multiple display styles
// ============================================================

import SwiftUI

struct CategoryBadgeView: View {
    let category: String
    var style: BadgeStyle = .pill
    
    enum BadgeStyle {
        case pill, chip, label, compact
    }
    
    var body: some View {
        switch style {
        case .pill:    pillBadge
        case .chip:    chipBadge
        case .label:   labelBadge
        case .compact: compactBadge
        }
    }
    
    // MARK: - Pill (white on color, for banners)
    private var pillBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: Constants.CategoryColors.icon(for: category))
                .font(.caption2.weight(.semibold))
            Text(category)
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white.opacity(0.2))
        .foregroundStyle(.white)
        .clipShape(Capsule())
    }
    
    // MARK: - Chip (tinted, for lists)
    private var chipBadge: some View {
        Text(category)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Constants.CategoryColors.color(for: category).opacity(0.12))
            .foregroundStyle(Constants.CategoryColors.color(for: category))
            .clipShape(Capsule())
    }
    
    // MARK: - Label (icon + text, for detail rows)
    private var labelBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: Constants.CategoryColors.icon(for: category))
                .font(.subheadline)
                .foregroundStyle(Constants.CategoryColors.color(for: category))
            Text(category)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Constants.CategoryColors.color(for: category))
        }
    }
    
    // MARK: - Compact (small dot + text)
    private var compactBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Constants.CategoryColors.color(for: category))
                .frame(width: 6, height: 6)
            Text(category)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
