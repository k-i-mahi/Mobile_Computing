// ============================================================
// EditEventView.swift
// Edit an existing event (creator or admin only)
// ============================================================

import SwiftUI
import FirebaseFirestore

struct EditEventView: View {
    let event: FirestoreEvent
    @EnvironmentObject var firestoreManager: FirestoreEventManager
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var category: String
    @State private var venue: String
    @State private var date: Date
    @State private var endDate: Date
    @State private var maxSeats: Int
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let categories = ["General", "Academic", "Sports", "Cultural", "Tech", "Social", "Workshop", "Other"]

    init(event: FirestoreEvent) {
        self.event = event
        _title       = State(initialValue: event.title)
        _description = State(initialValue: event.description)
        _category    = State(initialValue: event.category)
        _venue       = State(initialValue: event.venue)
        _date        = State(initialValue: event.date.dateValue())
        _endDate     = State(initialValue: event.endDate?.dateValue() ?? event.date.dateValue().addingTimeInterval(3600))
        _maxSeats    = State(initialValue: event.maxSeats)
    }

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
                }
                if let error = errorMessage {
                    Section {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(!isFormValid || isSubmitting)
                }
            }
            .disabled(isSubmitting)
        }
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !venue.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveChanges() {
        isSubmitting = true
        errorMessage = nil

        var updated = event
        updated.title       = title.trimmingCharacters(in: .whitespaces)
        updated.description = description.trimmingCharacters(in: .whitespaces)
        updated.category    = category
        updated.venue       = venue.trimmingCharacters(in: .whitespaces)
        updated.date        = Timestamp(date: date)
        updated.endDate     = Timestamp(date: endDate)
        updated.maxSeats    = maxSeats
        updated.updatedAt   = Timestamp(date: Date())

        Task {
            do {
                try await firestoreManager.updateEvent(updated)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
