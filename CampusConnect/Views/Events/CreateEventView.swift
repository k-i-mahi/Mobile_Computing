// ============================================================
// CreateEventView.swift
// Professional form to create a new Firestore event
// ============================================================

import SwiftUI
import PhotosUI

struct CreateEventView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var venue = ""
    @State private var selectedDate = Date()
    @State private var category = "Tech"
    @State private var seats = ""
    @State private var organizerName = ""
    @State private var organizerRole = ""
    @State private var hostEmail = ""
    @State private var hostPhone = ""
    @State private var organizationName = ""
    @State private var hostIdentityType = "PERSONAL"
    @State private var registrationLink = ""
    @State private var socialLinksText = ""
    @State private var agendaText = ""
    @State private var speakersText = ""
    @State private var faqQuestion = ""
    @State private var faqAnswer = ""
    @State private var faqItems: [EventFAQ] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var previewImage: UIImage?
    @State private var coverUploadURL: String?
    @State private var coverUploadPublicID: String?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private let manager = FirestoreEventManager()
    
    var body: some View {
        NavigationStack {
            Form {
                // Event Details
                Section {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Select Cover Photo (Optional)")
                            Spacer()
                            if selectedPhotoData != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Constants.Colors.success)
                            }
                        }
                    }

                    Group {
                        if let previewImage {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack(alignment: .bottomLeading) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Constants.CategoryColors.gradient(for: category))

                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.28)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )

                                HStack {
                                    Label("Gradient cover will be used", systemImage: "wand.and.stars")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(category)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.white.opacity(0.2), in: Capsule())
                                        .foregroundStyle(.white)
                                }
                                .padding(12)
                            }
                        }
                    }
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

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
                
                // Organizer
                Section {
                    Text("Make sure the organization name and host identity are valid. Using false information may lead to permanent access revocation.")
                        .font(.caption)
                        .foregroundStyle(Constants.Colors.warning)

                    Picker("Post As", selection: $hostIdentityType) {
                        Text("Personal Identity").tag("PERSONAL")
                        Text("Club / Organization").tag("ORGANIZATION")
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "building.2.fill")
                            .foregroundStyle(.purple)
                            .frame(width: 20)
                        TextField("Organization / Club", text: $organizationName)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Constants.Colors.brandGradientStart)
                            .frame(width: 20)
                        TextField("Host Name", text: $organizerName)
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "briefcase.fill")
                            .foregroundStyle(.purple)
                            .frame(width: 20)
                        TextField("Host Role (e.g. Club President)", text: $organizerRole)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(Constants.Colors.brandGradientStart)
                            .frame(width: 20)
                        TextField("Host Email", text: $hostEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(Constants.Colors.success)
                            .frame(width: 20)
                        TextField("Host Contact Number", text: $hostPhone)
                            .keyboardType(.phonePad)
                    }
                } header: {
                    Label("Organizer Info", systemImage: "person.text.rectangle")
                }

                Section {
                    TextField("Registration Form Link (optional)", text: $registrationLink)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)

                    TextField("Social Links (comma-separated)", text: $socialLinksText)
                        .textInputAutocapitalization(.never)

                    TextField("Agenda Items (comma-separated)", text: $agendaText)
                    TextField("Speakers / Performers (comma-separated)", text: $speakersText)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("FAQ")
                            .font(.subheadline.weight(.semibold))
                        TextField("Question", text: $faqQuestion)
                        TextField("Answer", text: $faqAnswer)
                        Button("Add FAQ") {
                            let q = faqQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                            let a = faqAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !q.isEmpty, !a.isEmpty else { return }
                            faqItems.append(EventFAQ(question: q, answer: a))
                            faqQuestion = ""
                            faqAnswer = ""
                        }
                        .disabled(faqQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || faqAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if !faqItems.isEmpty {
                            ForEach(Array(faqItems.enumerated()), id: \.offset) { idx, item in
                                Text("• \(item.question)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            faqItems.remove(at: idx)
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                            }
                        }
                    }
                } header: {
                    Label("Extended Details", systemImage: "list.bullet.clipboard")
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
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        selectedPhotoData = data
                        previewImage = UIImage(data: data)
                        coverUploadURL = nil
                        coverUploadPublicID = nil
                    }
                }
            }
            .onAppear {
                if hostEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    hostEmail = authViewModel.currentEmail
                }
            }
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
    
    private func submitEvent() async {
        errorMessage = nil
        let dateStr = DateFormatterHelper.string(from: selectedDate)
        
        let validation = ValidationService.validateRichEventForm(
            title: title,
            venue: venue,
            hostName: organizerName,
            hostEmail: hostEmail,
            hostPhone: hostPhone,
            organizationName: organizationName,
            description: description,
            registrationLink: registrationLink,
            category: category
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

        if let imageData = selectedPhotoData,
           coverUploadURL == nil || coverUploadPublicID == nil {
            do {
                let upload = try await CloudinaryUploadService.shared.uploadImage(imageData)
                coverUploadURL = upload.secureURL
                coverUploadPublicID = upload.publicID
            } catch {
                errorMessage = error.localizedDescription.isEmpty ? "Cloudinary upload failed." : error.localizedDescription
                HapticManager.notification(.error)
                isSubmitting = false
                return
            }
        }
        
        let newEvent = FirestoreEvent(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            venue: venue.trimmingCharacters(in: .whitespaces),
            date: dateStr,
            category: category,
            creatorUid: uid,
            creatorEmail: authViewModel.currentEmail,
            seats: Int(seats),
            organizerName: organizerName.trimmingCharacters(in: .whitespaces).isEmpty
                ? authViewModel.currentDisplayName
                : organizerName.trimmingCharacters(in: .whitespaces),
            organizerRole: organizerRole.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Event Organizer"
                : organizerRole.trimmingCharacters(in: .whitespaces),
            hostEmail: hostEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            hostPhone: hostPhone.trimmingCharacters(in: .whitespacesAndNewlines),
            imageURL: coverUploadURL,
            imagePublicId: coverUploadPublicID,
            hostIdentityType: hostIdentityType,
            organizationName: organizationName.trimmingCharacters(in: .whitespacesAndNewlines),
            registrationLink: registrationLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : registrationLink.trimmingCharacters(in: .whitespacesAndNewlines),
            socialLinks: listFromCSV(socialLinksText),
            agenda: listFromCSV(agendaText),
            speakers: listFromCSV(speakersText),
            faqs: faqItems,
            status: EventLifecycleStatus.pendingApproval.rawValue,
            isApproved: false
        )
        
        do {
            try await manager.createEvent(newEvent)
            isSubmitting = false
            successMessage = manager.successMessage ?? "Event Created Successfully! Submitted for ADMIN approval"
            try? await Task.sleep(nanoseconds: 1_300_000_000)
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
