// ============================================================
// CreateEventView.swift
// Form for creating a new campus event
// ============================================================

import SwiftUI
import FirebaseFirestore

struct CreateEventView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var firestoreManager: FirestoreEventManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var category = "General"
    @State private var venue = ""
    @State private var date = Date().addingTimeInterval(3600)
    @State private var endDate = Date().addingTimeInterval(7200)
    @State private var maxSeats = 50
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let categories = ["General", "Academic", "Sports", "Cultural", "Tech", "Social", "Workshop", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Location & Time") {
                    TextField("Venue", text: $venue)
                    DatePicker("Start Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End Date", selection: $endDate, in: date..., displayedComponents: [.date, .hourAndMinute])
                }
                Section("Capacity") {
                    Stepper("Max Seats: \(maxSeats)", value: $maxSeats, in: 0...500, step: 5)
                    Text(maxSeats == 0 ? "Unlimited" : "\(maxSeats) seats")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { submitEvent() }
                        .disabled(!isFormValid || isSubmitting)
                }
            }
            .disabled(isSubmitting)
        }
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !venue.trimmingCharacters(in: .whitespaces).isEmpty &&
        endDate > date
    }

    private func submitEvent() {
        guard let uid = authViewModel.currentUID else { return }
        isSubmitting = true
        errorMessage = nil

        let event = FirestoreEvent(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            category: category,
            venue: venue.trimmingCharacters(in: .whitespaces),
            date: Timestamp(date: date),
            endDate: Timestamp(date: endDate),
            organizerName: authViewModel.currentDisplayName,
            creatorUid: uid,
            status: authViewModel.role == .admin ? "approved" : "pending",
            maxSeats: maxSeats,
            rsvpCount: 0,
            imageURL: nil,
            tags: [],
            createdAt: Timestamp(date: Date())
        )

        Task {
            do {
                try await firestoreManager.createEvent(event)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
