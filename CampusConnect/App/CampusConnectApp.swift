// ============================================================
// CampusConnectApp.swift
// App entry point — Firebase init, global environment injection
// ============================================================

import SwiftUI
import Firebase

@main
struct CampusConnectApp: App {
    
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var themeManager = ThemeManager()
    
    init() {
        FirebaseApp.configure()
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            AuthRouterView()
                .environmentObject(authViewModel)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
    
    private func configureAppearance() {
        // Tab bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().standardAppearance = tabAppearance
        
        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold)
        ]
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().standardAppearance = navAppearance
    }
}
