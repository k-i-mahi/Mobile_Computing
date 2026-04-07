// ============================================================
// EditEventView.swift
// Edit an existing Firestore event with pre-populated fields
// ============================================================

import SwiftUI

struct EditEventView: View {
    let event: FirestoreEvent
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var venue: String
    @State private var selectedDate: Date
    @State private var category: String
    @State private var seats: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    private let manager = FirestoreEventManager()
    
    init(event: FirestoreEvent) {
        self.event = event
        _title       = State(initialValue: event.title)
        _description = State(initialValue: event.description)
        _venue       = State(initialValue: event.venue)
        _category    = State(initialValue: event.category)
        _selectedDate = State(initialValue: DateFormatterHelper.date(from: event.date) ?? Date())
        _seats       = State(initialValue: event.seats.map(String.init) ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Event Title", text: $title)
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Description")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                    }
                } header: {
                    Label("Event Details", systemImage: "square.and.pencil")
                }
                
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(Constants.Colors.danger)
                            .frame(width: 20)
                        TextField("Venue", text: $venue)
                    }
                    DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])
                    HStack(spacing: 12) {
                        Image(systemName: "chair.fill")
                            .foregroundStyle(Constants.Colors.accent)
                            .frame(width: 20)
                        TextField("Total Seats (optional)", text: $seats)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Label("Location & Time", systemImage: "location.fill")
                }
                
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(Constants.eventCategories, id: \.self) { cat in
                            Label(cat, systemImage: Constants.CategoryColors.icon(for: cat))
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Constants.CategoryColors.color(for: category))
                } header: {
                    Label("Category", systemImage: "tag.fill")
                }
                
                if let error = errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(Constants.Colors.danger)
                            Text(error).font(.footnote).foregroundStyle(Constants.Colors.danger)
                        }
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
                    Button {
                        Task { await updateEvent() }
                    } label: {
                        Text("Update")
                            .fontWeight(.semibold)
                            .foregroundStyle(Constants.Colors.brandGradientStart)
                    }
                    .disabled(isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(1.2)
                        Text("Updating…")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(28)
                    .background(.ultraThickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }
    
    private func updateEvent() async {
        let dateStr = DateFormatterHelper.string(from: selectedDate)
        let validation = ValidationService.validateEvent(title: title, venue: venue, date: dateStr, category: category)
        guard validation.isValid else {
            errorMessage = validation.message
            HapticManager.notification(.warning)
            return
        }
        
        isSubmitting = true
        var updated = event
        updated.title       = title.trimmingCharacters(in: .whitespaces)
        updated.description = description.trimmingCharacters(in: .whitespaces)
        updated.venue       = venue.trimmingCharacters(in: .whitespaces)
        updated.date        = dateStr
        updated.category    = category
        updated.seats       = Int(seats)
        
        do {
            try await manager.updateEvent(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
        }
        isSubmitting = false
    }
}
