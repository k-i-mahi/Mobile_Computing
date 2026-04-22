// ============================================================
// ViewExtensions.swift
// Custom view modifiers, shape extensions, and haptic helpers
// ============================================================

import SwiftUI
import Combine

// MARK: - Card Style Modifier
struct CardModifier: ViewModifier {
    var cornerRadius: CGFloat = Constants.Design.cardCornerRadius
    var shadowRadius: CGFloat = Constants.Design.cardShadowRadius
    
    func body(content: Content) -> some View {
        content
            .background(Constants.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(Constants.Design.cardShadowOpacity), radius: shadowRadius, x: 0, y: 4)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = Constants.Design.cardCornerRadius, shadow: CGFloat = Constants.Design.cardShadowRadius) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius, shadowRadius: shadow))
    }
}

// MARK: - Shimmer Loading Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.2), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width * 1.6 - geo.size.width * 0.3)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Stagger Animation Helper
extension View {
    func staggeredAppear(index: Int, show: Bool) -> some View {
        self
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 20)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.78).delay(Double(index) * 0.06),
                value: show
            )
    }
}

// MARK: - Haptic Feedback
enum HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
#if targetEnvironment(simulator)
        return
#else
        UIImpactFeedbackGenerator(style: style).impactOccurred()
#endif
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
#if targetEnvironment(simulator)
        return
#else
        UINotificationFeedbackGenerator().notificationOccurred(type)
#endif
    }
    
    static func selection() {
#if targetEnvironment(simulator)
        return
#else
        UISelectionFeedbackGenerator().selectionChanged()
#endif
    }
}

// MARK: - Rounded Specific Corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// MARK: - Conditional Modifier
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
