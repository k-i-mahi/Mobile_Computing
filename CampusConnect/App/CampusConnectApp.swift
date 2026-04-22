// ============================================================
// CampusConnectApp.swift
// App entry point — Firebase init, global environment injection
// ============================================================

import SwiftUI
import Firebase
import FirebaseAppCheck
import GoogleSignIn
import UIKit

final class CampusConnectAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        }
        return DeviceCheckProvider(app: app)
    }
}

@MainActor
final class CampusConnectAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
#if DEBUG
    // DEBUG uses App Check debug provider so simulator and dev builds can run with enforcement enabled.
    AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
#else
    AppCheck.setAppCheckProviderFactory(CampusConnectAppCheckProviderFactory())
#endif
        FirebaseApp.configure()
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct CampusConnectApp: App {
	@UIApplicationDelegateAdaptor(CampusConnectAppDelegate.self) var appDelegate
    
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var deepLinkManager = DeepLinkManager()
    @StateObject private var notificationsViewModel = NotificationsViewModel()
    
    init() {
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            AuthRouterView()
                .environmentObject(authViewModel)
                .environmentObject(themeManager)
                .environmentObject(deepLinkManager)
                .environmentObject(notificationsViewModel)
                .preferredColorScheme(themeManager.colorScheme)
                .onOpenURL { url in
                    if !GIDSignIn.sharedInstance.handle(url) {
                        deepLinkManager.handle(url)
                    }
                }
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
