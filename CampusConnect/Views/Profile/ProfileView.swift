// ============================================================
// ProfileView.swift
// User profile with editable fields, avatar, sign-out
// ============================================================

import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var profileVM = ProfileViewModel()

    @State private var isEditing = false
    @State private var nameField  = ""
    @State private var bioField   = ""
    @State private var deptField  = ""
    @State private var showSignOutAlert = false
    @State private var showSettings = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var previewImage: UIImage?
    @State private var isUploadingPhoto = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerCard

                accountStatusCard

                if authVM.role == .admin {
                    NavigationLink {
                        AdminPanelView()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.headline)
                                .foregroundStyle(Constants.Colors.brandGradientStart)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Admin Panel")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Review approvals, reports, moderation")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius))
                    }
                    .buttonStyle(.plain)
                }

                if isEditing {
                    editSection
                } else {
                    infoSection
                }

                signOutButton
            }
            .padding(16)
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    HapticManager.impact(.light)
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if isEditing { saveProfile() }
                    withAnimation(.spring(response: 0.35)) {
                        isEditing.toggle()
                    }
                } label: {
                    Text(isEditing ? "Save" : "Edit")
                        .fontWeight(.semibold)
                        .foregroundStyle(Constants.Colors.brandGradientStart)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(themeManager)
        }
        .task {
            if let uid = authVM.currentUID {
                await profileVM.loadProfile(uid: uid, email: authVM.currentEmail)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    selectedPhotoData = data
                    previewImage = UIImage(data: data)
                }
            }
        }
        .onChange(of: profileVM.profile) { _, profile in
            guard let p = profile else { return }
            nameField = p.displayName
            bioField  = p.bio ?? ""
            deptField = p.department
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) { authVM.signOut() }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .overlay {
            if isUploadingPhoto {
                Color.black.opacity(0.2).ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Uploading profile photo...")
                        .font(.caption)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .alert("Profile Update", isPresented: Binding(
            get: { profileVM.errorMessage != nil },
            set: { if !$0 { profileVM.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(profileVM.errorMessage ?? "")
        }
    }

    private var accountStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Account & Preferences")
                .font(.subheadline.weight(.semibold))

            HStack {
                Text("Status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(profileVM.profile?.accountStatus ?? UserRestrictionStatus.active.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Constants.Colors.warning.opacity(0.16))
                    .clipShape(Capsule())
            }

            HStack {
                Text("Warnings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(profileVM.profile?.warningCount ?? 0)")
                    .font(.caption.weight(.semibold))
            }

            HStack {
                Text("Campus Gmail")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text((profileVM.profile?.gmailConnected ?? false) ? "Connected" : "Not Connected")
                    .font(.caption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius))
    }

    // MARK: – Header Card
    private var headerCard: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else if let urlString = profileVM.profile?.photoURL,
                              let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            default:
                                Circle()
                                    .fill(Constants.Colors.brandGradient)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(initials)
                                            .font(.title.weight(.bold))
                                            .foregroundStyle(.white)
                                    )
                            }
                        }
                    } else {
                        Circle()
                            .fill(Constants.Colors.brandGradient)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(initials)
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(.white)
                            )
                    }
                }

                if isEditing {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "camera.fill")
                            .font(.caption.weight(.bold))
                            .padding(8)
                            .background(Constants.Colors.brandGradientStart, in: Circle())
                            .foregroundStyle(.white)
                    }
                }
            }

            if let p = profileVM.profile, !p.displayName.isEmpty {
                Text(p.displayName)
                    .font(.title3.weight(.bold))
            }

            if let email = profileVM.profile?.email {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(profileVM.profile?.displayJoinDate ?? "")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: – Info Section (read mode)
    private var infoSection: some View {
        VStack(spacing: 0) {
            profileRow(icon: "person.fill", color: Constants.Colors.brandGradientStart, label: "Name", value: profileVM.profile?.displayName ?? "—")
            Divider().padding(.leading, 56)
            profileRow(icon: "text.quote", color: Constants.Colors.accent, label: "Bio", value: profileVM.profile?.bio ?? "—")
            Divider().padding(.leading, 56)
            profileRow(icon: "building.2.fill", color: Constants.Colors.success, label: "Department", value: profileVM.profile?.department ?? "—")
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius))
    }

    // MARK: – Edit Section
    private var editSection: some View {
        VStack(spacing: 14) {
            editField(icon: "person.fill", color: Constants.Colors.brandGradientStart, placeholder: "Your name", text: $nameField)
            editField(icon: "text.quote", color: Constants.Colors.accent, placeholder: "Short bio", text: $bioField)
            editField(icon: "building.2.fill", color: Constants.Colors.success, placeholder: "Department", text: $deptField)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: – Sign Out
    private var signOutButton: some View {
        Button {
            showSignOutAlert = true
            HapticManager.impact(.medium)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Constants.Colors.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Constants.Colors.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: – Helpers
    private var initials: String {
        let name = profileVM.profile?.displayName ?? ""
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func saveProfile() {
        Task {
            profileVM.updateField(\.displayName, value: nameField.trimmingCharacters(in: .whitespaces))
            let trimmedBio = bioField.trimmingCharacters(in: .whitespaces)
            profileVM.updateField(\.bio, value: trimmedBio.isEmpty ? nil : trimmedBio)
            profileVM.updateField(\.department, value: deptField.trimmingCharacters(in: .whitespaces))

            if let photoData = selectedPhotoData {
                do {
                    isUploadingPhoto = true
                    let upload = try await CloudinaryUploadService.shared.uploadImage(
                        photoData,
                        folder: "campusconnect/profiles",
                        uploadPreset: Constants.cloudinaryProfilesUploadPreset
                    )
                    profileVM.updateField(\.photoURL, value: upload.secureURL)
                } catch {
                    profileVM.errorMessage = error.localizedDescription.isEmpty ? "Cloudinary upload failure." : error.localizedDescription
                    isUploadingPhoto = false
                    return
                }
                isUploadingPhoto = false
            }

            await profileVM.saveProfile()
        }
    }

    private func profileRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func editField(icon: String, color: Color, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(color)
            }
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
        }
    }
}
