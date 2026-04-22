// ============================================================
// ResetPasswordView.swift
// Set and confirm new password using Firebase reset code
// ============================================================

import SwiftUI

struct ResetPasswordView: View {
    let email: String

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false

    var body: some View {
        ZStack {
            Constants.Colors.brandGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: 40)

                    VStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Reset Password")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Set your new password and confirm to update it.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.88))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 16) {
                        CCSecureField(
                            icon: "lock.fill",
                            placeholder: "Set new password",
                            text: $newPassword,
                            isVisible: $showNewPassword
                        )

                        CCSecureField(
                            icon: "lock.rotation",
                            placeholder: "Confirm new password",
                            text: $confirmPassword,
                            isVisible: $showConfirmPassword
                        )

                        if let error = authViewModel.authError {
                            resetBanner(error)
                        }

                        Button {
                            HapticManager.impact(.medium)
                            Task {
                                let success = await authViewModel.updatePassword(
                                    email: email,
                                    newPassword: newPassword,
                                    confirmPassword: confirmPassword
                                )
                                if success {
                                    dismiss()
                                }
                            }
                        } label: {
                            Group {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("Update Password")
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
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 20)
                }
            }
        }
        .navigationTitle("New Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resetBanner(_ message: String) -> some View {
        let lower = message.lowercased()
        let isSuccess = lower.contains("updated successfully")

        return HStack(spacing: 10) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isSuccess ? Constants.Colors.success : Constants.Colors.danger)
                .font(.subheadline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(14)
        .background((isSuccess ? Constants.Colors.success : Constants.Colors.danger).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
