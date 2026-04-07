// ============================================================
// CreateEventView.swift
// Professional form to create a new Firestore event
// ============================================================

import SwiftUI

struct CreateEventView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var venue = ""
    @State private var selectedDate = Date()
    @State private var category = "Tech"
    @State private var seats = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    private let manager = FirestoreEventManager()
    
    var body: some View {
        NavigationStack {
            Form {
                // Event Details
                Section {
                    TextField("Event Title", text: $title)
                        .font(.body)
                    
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Describe your event…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                    }
                } header: {
                    Label("Event Details", systemImage: "square.and.pencil")
                }
                
                // Location & Time
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(Constants.Colors.danger)
                            .frame(width: 20)
                        TextField("Venue", text: $venue)
                    }
                    
                    DatePicker("Date", selection: $selectedDate, in: Date()..., displayedComponents: [.date])
                    
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
                
                // Category
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
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(Constants.Colors.danger)
                        }
                    }
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submitEvent() }
                    } label: {
                        Text("Create")
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
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Creating event…")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(28)
                    .background(.ultraThickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }
    
    private func submitEvent() async {
        errorMessage = nil
        let dateStr = DateFormatterHelper.string(from: selectedDate)
        
        let validation = ValidationService.validateEvent(
            title: title, venue: venue, date: dateStr, category: category
        )
        guard validation.isValid else {
            errorMessage = validation.message
            HapticManager.notification(.warning)
            return
        }
        
        guard let uid = authViewModel.currentUID else {
            errorMessage = "You must be signed in to create an event."
            return
        }
        
        isSubmitting = true
        
        let newEvent = FirestoreEvent(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            venue: venue.trimmingCharacters(in: .whitespaces),
            date: dateStr,
            category: category,
            creatorUid: uid,
            creatorEmail: authViewModel.currentEmail,
            seats: Int(seats)
        )
        
        do {
            try await manager.createEvent(newEvent)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
        }
        isSubmitting = false
    }
}
