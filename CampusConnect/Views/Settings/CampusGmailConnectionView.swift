import SwiftUI
import FirebaseFirestore

struct CampusGmailConnectionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var connectionState: GmailConnectionState = .notConnected
    @State private var localGoogleSessionAvailable = false
    @State private var isLoading = false
    @State private var statusMessage: String?

    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 42))
                .foregroundStyle(Constants.Colors.brandGradient)

            Text("Campus Gmail Integration")
                .font(.title3.weight(.bold))

            Text("Optional feature: connect Gmail to fetch official mail metadata (subject, sender, date). KUET Notice Board remains the primary source.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("Status: \(connectionState.rawValue)")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Constants.Colors.brandGradientStart.opacity(0.14))
                .clipShape(Capsule())

            if connectionState == .connected && !localGoogleSessionAvailable {
                Text("Reconnect this device to sync KUET mail. Past fetched emails remain in notifications.")
                    .font(.caption)
                    .foregroundStyle(Constants.Colors.warning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 10) {
                if connectionState == .connected {
                    Button(localGoogleSessionAvailable ? "Sync Now" : "Reconnect") {
                        Task {
                            if localGoogleSessionAvailable {
                                await syncConnectedMail()
                            } else {
                                await updateConnectionState(.connected)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)

                    Button("Turn Off") {
                        Task { await updateConnectionState(.notConnected) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                } else {
                    Button("Turn On") {
                        Task { await updateConnectionState(.connected) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                }
            }

            if isLoading {
                ProgressView()
            }

            Spacer()
        }
        .padding(.top, 30)
        .navigationTitle("Campus Gmail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadConnectionState()
        }
    }

    private func loadConnectionState() async {
        guard let uid = authViewModel.currentUID else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let doc = try await db.collection("gmail_connection_settings").document(uid).getDocument()
            if let data = doc.data(), let connected = data["connected"] as? Bool {
                connectionState = connected ? .connected : .notConnected
            } else {
                let userDoc = try? await db.collection("users").document(uid).getDocument()
                let fromProfile = userDoc?.data()?["gmailConnected"] as? Bool
                connectionState = (fromProfile == true) ? .connected : .notConnected
            }
            if connectionState == .connected {
                localGoogleSessionAvailable = await CampusGmailService.shared.restoreSignedInUser(
                    campusEmail: authViewModel.currentEmail
                )
                statusMessage = localGoogleSessionAvailable ? nil : "KUET mail is connected for this account, but this simulator/device needs Google reconnect."
            } else {
                localGoogleSessionAvailable = false
                statusMessage = nil
            }
        } catch {
            statusMessage = "Could not load Gmail connection state: \(error.localizedDescription)"
        }
    }

    private func updateConnectionState(_ state: GmailConnectionState) async {
        guard let uid = authViewModel.currentUID else {
            statusMessage = "Sign in to manage Gmail connection."
            return
        }
        let email = authViewModel.currentEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ValidationService.isValidCampusEmail(email) else {
            statusMessage = "Use your @\(Constants.campusEmailDomain) account to enable KUET mail."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if state == .connected {
                let result = try await CampusGmailService.shared.connectAndSync(uid: uid, campusEmail: email)
                connectionState = .connected
                localGoogleSessionAvailable = true
                statusMessage = result.storedCount > 0
                    ? "KUET mail sync enabled. \(result.storedCount) email metadata item(s) updated."
                    : "KUET mail sync enabled. New email metadata will appear when available."
            } else {
                try await CampusGmailService.shared.disconnect(uid: uid, campusEmail: email)
                connectionState = .notConnected
                localGoogleSessionAvailable = false
                statusMessage = "KUET mail sync disabled. Past fetched emails will remain in notifications."
            }
        } catch {
            statusMessage = error.localizedDescription
            if state == .connected {
                localGoogleSessionAvailable = false
            }
        }
    }

    private func syncConnectedMail() async {
        guard let uid = authViewModel.currentUID else {
            statusMessage = "Sign in to manage Gmail connection."
            return
        }
        let email = authViewModel.currentEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ValidationService.isValidCampusEmail(email) else {
            statusMessage = "Use your @\(Constants.campusEmailDomain) account to enable KUET mail."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await CampusGmailService.shared.syncIfPossible(uid: uid, campusEmail: email)
            localGoogleSessionAvailable = true
            statusMessage = "KUET mail updated. \(result.storedCount) email metadata item(s) checked."
        } catch {
            statusMessage = error.localizedDescription
            localGoogleSessionAvailable = false
        }
    }
}

private enum GmailConnectionState: String {
    case notConnected = "Not Connected"
    case connected = "Connected"
    case revoked = "Access Revoked"
}
