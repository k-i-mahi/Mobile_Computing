// ============================================================
// LoginView.swift
// Premium login + sign-up screen with rich visual design
// ============================================================

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUpMode = false
    @State private var showPassword = false
    @State private var appeared = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                backgroundLayer
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.bottom, 36)
                        
                        // Glass card for form
                        VStack(spacing: 20) {
                            formSection
                            
                            if let error = authViewModel.authError {
                                errorBanner(error)
                            }
                            
                            actionButton
                            
                            dividerSection
                            
                            toggleModeButton
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
    }
    
    // MARK: - Background
    private var backgroundLayer: some View {
        ZStack {
            Constants.Colors.brandGradient
                .ignoresSafeArea()
            
            // Decorative floating circles
            GeometryReader { geo in
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 300, height: 300)
                    .offset(x: -80, y: -60)
                
                Circle()
                    .fill(.white.opacity(0.04))
                    .frame(width: 200, height: 200)
                    .offset(x: geo.size.width - 100, y: geo.size.height * 0.3)
                
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 150, height: 150)
                    .offset(x: geo.size.width * 0.2, y: geo.size.height * 0.7)
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 88, height: 88)
                
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.7)
            
            Text("CampusConnect")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
            
            Text(isSignUpMode ? "Create your account" : "Welcome back")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
        }
    }
    
    // MARK: - Form
    private var formSection: some View {
        VStack(spacing: 14) {
            if isSignUpMode {
                CCTextField(
                    icon: "person.fill",
                    placeholder: "Full Name",
                    text: $displayName
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            CCTextField(
                icon: "envelope.fill",
                placeholder: "Email Address",
                text: $email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress
            )
            
            CCSecureField(
                icon: "lock.fill",
                placeholder: "Password",
                text: $password,
                isVisible: $showPassword
            )
        }
    }
    
    // MARK: - Error Banner
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.subheadline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer()
            Button {
                withAnimation { authViewModel.clearError() }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Action Button
    private var actionButton: some View {
        Button {
            HapticManager.impact(.medium)
            Task {
                if isSignUpMode {
                    await authViewModel.signUp(email: email, password: password, displayName: displayName)
                } else {
                    await authViewModel.signIn(email: email, password: password)
                }
            }
        } label: {
            Group {
                if authViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(isSignUpMode ? "Create Account" : "Sign In")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Constants.Design.buttonHeight)
            .background(
                LinearGradient(
                    colors: [
                        Constants.Colors.brandGradientStart,
                        Constants.Colors.brandGradientEnd
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Constants.Colors.brandGradientStart.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .disabled(authViewModel.isLoading)
    }
    
    // MARK: - Divider
    private var dividerSection: some View {
        HStack(spacing: 16) {
            Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
            Text("or")
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
        }
    }
    
    // MARK: - Toggle Mode
    private var toggleModeButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isSignUpMode.toggle()
                authViewModel.clearError()
                email = ""; password = ""; displayName = ""
            }
        } label: {
            HStack(spacing: 4) {
                Text(isSignUpMode ? "Already have an account?" : "Don't have an account?")
                    .foregroundStyle(.secondary)
                Text(isSignUpMode ? "Sign In" : "Sign Up")
                    .foregroundStyle(Constants.Colors.brandGradientStart)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
    }
}

// MARK: - Custom Text Field
struct CCTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(isFocused ? Constants.Colors.brandGradientStart : .secondary)
                .frame(width: 20)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.smallCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.smallCornerRadius)
                .stroke(isFocused ? Constants.Colors.brandGradientStart.opacity(0.5) : .clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Custom Secure Field
struct CCSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(isFocused ? Constants.Colors.brandGradientStart : .secondary)
                .frame(width: 20)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textContentType(.password)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($isFocused)
            
            Button { isVisible.toggle() } label: {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.smallCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.smallCornerRadius)
                .stroke(isFocused ? Constants.Colors.brandGradientStart.opacity(0.5) : .clear, lineWidth: 1.5)
        )
    }
}
