import SwiftUI

struct OnboardingView: View {
    var onDone: () -> Void
    @State private var selectedPage = 0

    private struct OnboardingPage: Identifiable {
        let id: Int
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
    }

    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                id: 0,
                title: "Campus-Only Community",
                subtitle: "Verified university users only. Safer and more trusted event discovery.",
                icon: "checkmark.shield.fill",
                color: Constants.Colors.brandGradientStart
            ),
            OnboardingPage(
                id: 1,
                title: "Social Event Feed",
                subtitle: "Upvote, discuss, and follow trending events with native smooth interactions.",
                icon: "sparkles.rectangle.stack.fill",
                color: Constants.Colors.accent
            ),
            OnboardingPage(
                id: 2,
                title: "Moderated and Reliable",
                subtitle: "Admin approval, reports, warnings, and policy enforcement keep information trustworthy.",
                icon: "person.badge.shield.checkmark.fill",
                color: Constants.Colors.warning
            )
        ]
    }

    var body: some View {
        VStack(spacing: 18) {
            TabView(selection: $selectedPage) {
                ForEach(pages) { page in
                    slide(
                        title: page.title,
                        subtitle: page.subtitle,
                        icon: page.icon,
                        color: page.color
                    )
                    .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack {
                Button("Skip") {
                    onDone()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

                Spacer()

                Button(selectedPage == pages.count - 1 ? "Get Started" : "Next") {
                    if selectedPage == pages.count - 1 {
                        onDone()
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedPage += 1
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Constants.Colors.brandGradientStart)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
        }
    }

    private func slide(title: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(color)
            Text(title)
                .font(.title2.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
