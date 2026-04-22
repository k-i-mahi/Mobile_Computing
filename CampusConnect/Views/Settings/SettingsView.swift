// ============================================================
// SettingsView.swift
// Theme selector, app info, and preferences
// ============================================================

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: – Appearance
                Section {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            withAnimation(.spring(response: 0.35)) {
                                themeManager.selectedTheme = theme
                            }
                            HapticManager.selection()
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeIconColor(theme).opacity(0.14))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: themeIcon(theme))
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(themeIconColor(theme))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(theme.description)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(themeSubtitle(theme))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if themeManager.selectedTheme == theme {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Constants.Colors.brandGradientStart)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                } header: {
                    Label("Appearance", systemImage: "paintbrush.fill")
                } footer: {
                    Text("Choose how CampusConnect looks on your device.")
                }
                
                // MARK: – About
                Section {
                    infoRow(icon: "info.circle.fill", color: Constants.Colors.accent, label: "Version", value: "1.0.0")
                    infoRow(icon: "hammer.fill", color: Constants.Colors.warning, label: "Build", value: "2025.1")
                    infoRow(icon: "swift", color: .orange, label: "Platform", value: "SwiftUI · iOS 17+")
                } header: {
                    Label("About", systemImage: "ellipsis.circle.fill")
                }

                Section {
                    NavigationLink {
                        CampusGmailConnectionView()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Constants.Colors.brandGradientStart.opacity(0.14))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "envelope.badge.fill")
                                    .font(.callout)
                                    .foregroundStyle(Constants.Colors.brandGradientStart)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connect Campus Gmail")
                                    .font(.subheadline.weight(.medium))
                                Text("Optional metadata-only integration")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Integrations", systemImage: "link")
                }
                
                // MARK: – Credits
                Section {
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "graduationcap.fill")
                            .font(.largeTitle)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Constants.Colors.brandGradientStart, Constants.Colors.brandGradientEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("CampusConnect")
                            .font(.headline)
                        Text("Bringing the campus together.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }
    
    // MARK: – Helpers
    private func themeIcon(_ theme: AppTheme) -> String {
        switch theme {
        case .system: return "gear"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
    
    private func themeIconColor(_ theme: AppTheme) -> Color {
        switch theme {
        case .system: return Constants.Colors.accent
        case .light:  return Constants.Colors.warning
        case .dark:   return Constants.Colors.brandGradientEnd
        }
    }
    
    private func themeSubtitle(_ theme: AppTheme) -> String {
        switch theme {
        case .system: return "Match your device settings"
        case .light:  return "Always use light mode"
        case .dark:   return "Always use dark mode"
        }
    }
    
    private func infoRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
