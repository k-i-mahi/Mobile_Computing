// ============================================================
// SharedComponents.swift
// Premium reusable Loading, Error, Empty, and Search views
// ============================================================

import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    var message: String = "Loading…"
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 4)
                    .frame(width: 48, height: 48)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        Constants.Colors.brandGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: isAnimating)
            }
            
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    var onRetry: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Constants.Colors.warning.opacity(0.12))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Constants.Colors.warning)
            }
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            if let retry = onRetry {
                Button {
                    HapticManager.impact(.light)
                    retry()
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Constants.Colors.brandGradientStart.opacity(0.1))
                        .foregroundStyle(Constants.Colors.brandGradientStart)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Constants.Colors.brandGradientStart.opacity(0.08))
                    .frame(width: 88, height: 88)
                
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(Constants.Colors.brandGradientStart.opacity(0.6))
            }
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            if let buttonTitle, let action {
                Button {
                    HapticManager.impact(.light)
                    action()
                } label: {
                    Label(buttonTitle, systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Constants.Colors.brandGradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Section Header
struct SectionHeaderView: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.bold))
                
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if let trailing, let action {
                Button(action: action) {
                    Text(trailing)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Constants.Colors.brandGradientStart)
                }
            }
        }
        .padding(.horizontal, Constants.Design.horizontalPadding)
    }
}

// MARK: - Action Card
struct ActionCardView: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Constants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Constants.Design.smallCornerRadius, style: .continuous))
        }
    }
}

// MARK: - Search Bar
struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search…"
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(isFocused ? Constants.Colors.brandGradientStart : .secondary)
                .font(.subheadline)
            
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
            
            if !text.isEmpty {
                Button {
                    text = ""
                    HapticManager.impact(.light)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Constants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.smallCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.smallCornerRadius)
                .stroke(isFocused ? Constants.Colors.brandGradientStart.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}
