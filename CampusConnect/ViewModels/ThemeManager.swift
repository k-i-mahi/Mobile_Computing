// ============================================================
// ThemeManager.swift
// Global theme toggle with persistence
// ============================================================

import SwiftUI
import Combine

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light  = "Light"
    case dark   = "Dark"
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
    
    var description: String {
        switch self {
        case .system: return "Follows your device settings"
        case .light:  return "Always use light appearance"
        case .dark:   return "Always use dark appearance"
        }
    }
}

final class ThemeManager: ObservableObject {
    
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    var colorScheme: ColorScheme? {
        switch selectedTheme {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
    
    init() {
        let saved = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.system.rawValue
        selectedTheme = AppTheme(rawValue: saved) ?? .system
    }
}
