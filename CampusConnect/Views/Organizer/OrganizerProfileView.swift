// ============================================================
// OrganizerProfileView.swift
// Organizer detail sheet and contact view
// ============================================================

import SwiftUI

// MARK: – Organizer Profile (single organizer)
struct OrganizerProfileView: View {
    let organizer: Organizer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            OrganizerDetailView(organizer: organizer)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

// MARK: – Detail
struct OrganizerDetailView: View {
    let organizer: Organizer
    @State private var showContact = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header card
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Constants.Colors.brandGradientStart, Constants.Colors.brandGradientEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        Text(organizer.initials)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.white)
                    }

                    Text(organizer.name)
                        .font(.title2.weight(.bold))

                    Text(organizer.role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(organizer.displayBio)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // Info rows
                VStack(spacing: 0) {
                    infoRow(icon: "building.2.fill", color: Constants.Colors.accent, label: "Department", value: organizer.department)
                    Divider().padding(.leading, 56)
                    if !organizer.email.isEmpty {
                        infoRow(icon: "envelope.fill", color: Constants.Colors.brandGradientStart, label: "Email", value: organizer.email)
                        Divider().padding(.leading, 56)
                    }
                    if let phone = organizer.phone, !phone.isEmpty {
                        infoRow(icon: "phone.fill", color: Constants.Colors.success, label: "Phone", value: phone)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius))

                // Contact button
                if organizer.hasContactInfo {
                    Button {
                        showContact = true
                        HapticManager.impact(.light)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                            Text("Get in Touch")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Constants.Colors.brandGradient, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(organizer.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showContact) {
            OrganizerContactView(organizer: organizer)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
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
}

// MARK: – Contact Sheet
struct OrganizerContactView: View {
    let organizer: Organizer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 52))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Constants.Colors.brandGradientStart)

                Text(organizer.name)
                    .font(.title3.weight(.bold))

                VStack(spacing: 12) {
                    if !organizer.email.isEmpty {
                        contactButton(icon: "envelope.fill", title: "Email", value: organizer.email, color: Constants.Colors.brandGradientStart)
                    }
                    if let phone = organizer.phone, !phone.isEmpty {
                        contactButton(icon: "phone.fill", title: "Call", value: phone, color: Constants.Colors.success)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func contactButton(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.14)).frame(width: 40, height: 40)
                Image(systemName: icon).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.medium))
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius))
    }
}
