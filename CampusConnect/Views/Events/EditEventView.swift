// ============================================================
// EditEventView.swift
// Edit an existing Firestore event with pre-populated fields
// ============================================================

import SwiftUI
import FirebaseFirestore

struct EditEventView: View {
    let event: FirestoreEvent
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var venue: String
    @State private var selectedDate: Date
    @State private var category: String
    @State private var seats: String
    @State private var organizationName: String
    @State private var hostEmail: String
    @State private var hostPhone: String
    @State private var registrationLink: String
    @State private var agendaText: String
    @State private var speakersText: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private let manager = FirestoreEventManager()
    
    init(event: FirestoreEvent) {
        self.event = event
        _title       = State(initialValue: event.title)
        _description = State(initialValue: event.description)
        _venue       = State(initialValue: event.venue)
        _category    = State(initialValue: event.category)
        _selectedDate = State(initialValue: DateFormatterHelper.date(from: event.date) ?? Date())
        _seats       = State(initialValue: event.seats.map(String.init) ?? "")
        _organizationName = State(initialValue: event.organizationName ?? "")
        _hostEmail = State(initialValue: event.hostEmail ?? "")
        _hostPhone = State(initialValue: event.hostPhone ?? "")
        _registrationLink = State(initialValue: event.registrationLink ?? "")
        _agendaText = State(initialValue: (event.agenda ?? []).joined(separator: ", "))
        _speakersText = State(initialValue: (event.speakers ?? []).joined(separator: ", "))
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

                Section {
                    TextField("Organization / Club", text: $organizationName)
                    TextField("Host Email", text: $hostEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Host Contact Number", text: $hostPhone)
                        .keyboardType(.phonePad)
                    TextField("Registration Link", text: $registrationLink)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("Agenda Items (comma-separated)", text: $agendaText)
                    TextField("Speakers (comma-separated)", text: $speakersText)
                } header: {
                    Label("Additional Details", systemImage: "list.bullet.rectangle")
                }

                if let reason = event.rejectionReason, !reason.isEmpty {
                    Section {
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(Constants.Colors.danger)
                    } header: {
                        Label("Rejection Feedback", systemImage: "exclamationmark.bubble.fill")
                    }
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
            .overlay(alignment: .bottom) {
                if let successMessage {
                    Text(successMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Constants.Colors.success.gradient, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4), value: successMessage)
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
        updated.organizationName = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.hostEmail = hostEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.hostPhone = hostPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.registrationLink = registrationLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : registrationLink.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.agenda = listFromCSV(agendaText)
        updated.speakers = listFromCSV(speakersText)
        updated.updatedAt = Timestamp(date: Date())
        
        let wasResubmission = event.lifecycleStatus == .rejected || event.lifecycleStatus == .draft

        do {
            try await manager.updateEvent(updated)
            isSubmitting = false
            successMessage = wasResubmission
                ? "Resubmitted for ADMIN approval"
                : (manager.successMessage ?? "Event updated successfully")
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
            isSubmitting = false
        }
    }

    private func listFromCSV(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
