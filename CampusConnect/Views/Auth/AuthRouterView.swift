// ============================================================
// AuthRouterView.swift
// Routes between Login and Dashboard with smooth transition
// ============================================================

import SwiftUI

struct AuthRouterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            if showSplash {
                splashScreen
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
