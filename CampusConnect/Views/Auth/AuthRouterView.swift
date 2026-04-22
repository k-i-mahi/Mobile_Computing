// ============================================================
// AuthRouterView.swift
// Routes between Login and Dashboard with smooth transition
// ============================================================

import SwiftUI

struct AuthRouterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSplash = true
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingSeen")
    
    var body: some View {
        ZStack {
            if showSplash {
                splashScreen
                    .transition(.opacity)
            } else if showOnboarding {
                OnboardingView {
                    UserDefaults.standard.set(true, forKey: "onboardingSeen")
                    withAnimation { showOnboarding = false }
                }
                .transition(.opacity)
            } else if authViewModel.accountStatus == .banned {
                bannedStateView
                    .transition(.opacity)
            } else if authViewModel.isSignedIn {
                DashboardView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                LoginView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.45), value: authViewModel.isSignedIn)
        .animation(.easeOut(duration: 0.4), value: showSplash)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showSplash = false }
            }
        }
    }

    private var bannedStateView: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Constants.Colors.danger)
                Text("Account Restricted")
                    .font(.title3.weight(.bold))
                Text("Your account has been permanently restricted. Contact campus admin for appeal details.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Button("Back to Login") {
                    authViewModel.signOut()
                }
                .buttonStyle(.borderedProminent)
                .tint(Constants.Colors.danger)
            }
        }
    }
    
    // MARK: - Splash Screen
    private var splashScreen: some View {
        ZStack {
            Constants.Colors.brandGradient
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
                
                Text("CampusConnect")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Your campus, connected")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
