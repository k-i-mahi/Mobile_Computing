// ============================================================
// FirestoreEventManager.swift
// Firestore CRUD with real-time listener for user events
// ============================================================

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class FirestoreEventManager: ObservableObject {
    
    @Published var userEvents: [FirestoreEvent] = []
    @Published var allEvents: [FirestoreEvent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var selectedSortOption: EventSortOption = .newest
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var allEventsListener: ListenerRegistration?
    private var approvedEventsListener: ListenerRegistration?
    private var legacyApprovedEventsListener: ListenerRegistration?
    private var ownEventsListener: ListenerRegistration?
    private var approvedFeedEvents: [FirestoreEvent] = []
    private var legacyApprovedFeedEvents: [FirestoreEvent] = []
    private var ownFeedEvents: [FirestoreEvent] = []
    private var approvedFeedLoaded = false
    private var legacyApprovedFeedLoaded = false
    private var ownFeedLoaded = true
    
    deinit {
        listener?.remove()
        allEventsListener?.remove()
        approvedEventsListener?.remove()
        legacyApprovedEventsListener?.remove()
        ownEventsListener?.remove()
    }
    
    // MARK: - Real-time listener for ALL events (Explore tab)
    func startListeningAllEvents(uid: String? = nil) {
        approvedEventsListener?.remove()
        legacyApprovedEventsListener?.remove()
        ownEventsListener?.remove()
        isLoading = true
        errorMessage = nil
        allEvents = []
        approvedFeedLoaded = false
        legacyApprovedFeedLoaded = false
        ownFeedLoaded = (uid == nil)
        approvedFeedEvents = []
        legacyApprovedFeedEvents = []
        ownFeedEvents = []

        approvedEventsListener = db.collection("events")
            .whereField("status", isEqualTo: EventLifecycleStatus.approved.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        self.approvedFeedLoaded = true
                        self.updateFeedLoadingState()
                        return
                    }
                    let fetched = (snapshot?.documents ?? []).compactMap { doc in
                        try? doc.data(as: FirestoreEvent.self)
                    }
                    self.approvedFeedEvents = fetched.filter { self.isExploreVisibleEvent($0) }
                    self.approvedFeedLoaded = true
                    self.mergeFeedEvents()
                }
            }

        legacyApprovedEventsListener = db.collection("events")
            .whereField("isApproved", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        self.legacyApprovedFeedLoaded = true
                        self.updateFeedLoadingState()
                        return
                    }
                    let fetched = (snapshot?.documents ?? []).compactMap { doc in
                        try? doc.data(as: FirestoreEvent.self)
                    }
                    self.legacyApprovedFeedEvents = fetched.filter { self.isExploreVisibleEvent($0) }
                    self.legacyApprovedFeedLoaded = true
                    self.mergeFeedEvents()
                }
            }

        guard let uid else { return }
        ownEventsListener = db.collection("events")
            .whereField("creatorUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        self.ownFeedLoaded = true
                        self.updateFeedLoadingState()
                        return
                    }
                    let fetched = (snapshot?.documents ?? []).compactMap { doc in
                        try? doc.data(as: FirestoreEvent.self)
                    }
                    self.ownFeedEvents = fetched.filter { self.isExploreVisibleEvent($0) }
                    self.ownFeedLoaded = true
                    self.mergeFeedEvents()
                }
            }
    }
    
    func stopListeningAllEvents() {
        allEventsListener?.remove()
        allEventsListener = nil
        approvedEventsListener?.remove()
        legacyApprovedEventsListener?.remove()
        ownEventsListener?.remove()
        approvedEventsListener = nil
        legacyApprovedEventsListener = nil
        ownEventsListener = nil
        approvedFeedEvents = []
        legacyApprovedFeedEvents = []
        ownFeedEvents = []
        allEvents = []
        approvedFeedLoaded = false
        legacyApprovedFeedLoaded = false
        ownFeedLoaded = true
    }

    // MARK: - Admin listener for all events (all lifecycle states)
    func startListeningAdminAllEvents() {
        allEventsListener?.remove()
        isLoading = true
        allEventsListener = db.collection("events")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    guard let snapshot else { return }
                    self.allEvents = snapshot.documents.compactMap { doc in
                        try? doc.data(as: FirestoreEvent.self)
                    }
                }
            }
    }
    
    // MARK: - Real-time listener for user's events
    func startListening(uid: String) {
        listener?.remove()
        isLoading = true
        errorMessage = nil
        listener = db.collection("events")
            .whereField("creatorUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    guard let snapshot else { return }
                    self.errorMessage = nil
                    self.userEvents = snapshot.documents.compactMap { doc in
                        try? doc.data(as: FirestoreEvent.self)
                    }.sorted {
                        ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
                    }
                }
            }
    }

    // MARK: - Admin listener for pending approvals
    func startListeningPendingApprovals() {
        allEventsListener?.remove()
        isLoading = true
        allEventsListener = db.collection("events")
            .whereField("status", isEqualTo: EventLifecycleStatus.pendingApproval.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    guard let snapshot else { return }
                    self.errorMessage = nil
                    self.allEvents = snapshot.documents.compactMap { doc in
                        try? doc.data(as: FirestoreEvent.self)
                    }.sorted {
                        ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
                    }
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: - Create
    func createEvent(_ event: FirestoreEvent) async throws {
        var newEvent = event
        let now = Timestamp(date: Date())
        newEvent.createdAt = now
        newEvent.updatedAt = now
        newEvent.status = EventLifecycleStatus.pendingApproval.rawValue
        newEvent.isApproved = false
        newEvent.trendingScore = 0
        newEvent.commentCount = 0
        newEvent.replyCount = 0
        newEvent.uniqueCommenterCount = 0
        newEvent.upvoteCount = 0
        newEvent.removedByAdmin = false
        try db.collection("events").addDocument(from: newEvent)
        successMessage = "Event Created Successfully! Submitted for ADMIN approval"
        HapticManager.notification(.success)
    }
    
    // MARK: - Update
    func updateEvent(_ event: FirestoreEvent) async throws {
        guard let id = event.id else { throw FirestoreError.missingID }
        let previousSnapshot = try? await db.collection("events").document(id).getDocument()
        let previousData = previousSnapshot?.data()
        var updated = event
        updated.updatedAt = Timestamp(date: Date())
        let wasResubmission = (updated.lifecycleStatus == .rejected || updated.lifecycleStatus == .draft)
        if updated.lifecycleStatus == .rejected || updated.lifecycleStatus == .draft {
            updated.status = EventLifecycleStatus.pendingApproval.rawValue
            updated.isApproved = false
        }
        try db.collection("events").document(id).setData(from: updated, merge: true)

        let previousVenue = previousData?["venue"] as? String
        let previousDate = previousData?["date"] as? String
        var changedFields: [String] = []
        if let previousVenue, previousVenue != updated.venue {
            changedFields.append("venue")
        }
        if let previousDate, previousDate != updated.date {
            changedFields.append("date/time")
        }
        if !changedFields.isEmpty {
            await ClientNotificationService.shared.notifyReminderFollowersOfEventChange(
                eventId: id,
                eventTitle: updated.title,
                actorUid: updated.creatorUid,
                changedFields: changedFields,
                venue: updated.venue,
                date: updated.date
            )
        }

        successMessage = wasResubmission
            ? "Resubmitted for ADMIN approval"
            : "Event updated and submitted for review."
        HapticManager.notification(.success)
    }
    
    // MARK: - Delete
    func deleteEvent(_ event: FirestoreEvent) async throws {
        guard let id = event.id else { throw FirestoreError.missingID }
        try await db.collection("events").document(id).setData([
            "status": EventLifecycleStatus.archived.rawValue,
            "archivedAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
        HapticManager.notification(.success)
    }
    
    // MARK: - Admin: Delete any event by ID
    func deleteEvent(id: String) async throws {
        try await db.collection("events").document(id).setData([
            "status": EventLifecycleStatus.removedByAdmin.rawValue,
            "removedByAdmin": true,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
        HapticManager.notification(.success)
    }

    // MARK: - Admin moderation
    func approveEvent(id: String, adminUID: String) async throws {
        try await db.collection("events").document(id).setData([
            "status": EventLifecycleStatus.approved.rawValue,
            "isApproved": true,
            "updatedAt": Timestamp(date: Date()),
            "rejectionReason": FieldValue.delete()
        ], merge: true)

        try await db.collection("admin_actions").addDocument(data: [
            "eventId": id,
            "action": "APPROVE_EVENT",
            "actorUid": adminUID,
            "createdAt": Timestamp(date: Date())
        ])

        successMessage = "event published!"
        HapticManager.notification(.success)
    }

    func rejectEvent(id: String, reason: String, adminUID: String) async throws {
        let historyItem: [String: Any] = [
            "reason": reason,
            "rejectedByUID": adminUID,
            "rejectedAt": Timestamp(date: Date())
        ]
        try await db.collection("events").document(id).setData([
            "status": EventLifecycleStatus.rejected.rawValue,
            "isApproved": false,
            "rejectionReason": reason,
            "updatedAt": Timestamp(date: Date()),
            "rejectionHistory": FieldValue.arrayUnion([historyItem])
        ], merge: true)

        try await db.collection("admin_actions").addDocument(data: [
            "eventId": id,
            "action": "REJECT_EVENT",
            "reason": reason,
            "actorUid": adminUID,
            "createdAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Social interaction
    func toggleUpvote(eventId: String, uid: String) async throws {
        let upvoteDoc = db.collection("events").document(eventId).collection("upvotes").document(uid)
        let eventDoc = db.collection("events").document(eventId)
        let snapshot = try await upvoteDoc.getDocument()
        if snapshot.exists {
            _ = try await db.runTransaction { transaction, _ in
                transaction.deleteDocument(upvoteDoc)
                transaction.updateData(["upvoteCount": FieldValue.increment(Int64(-1))], forDocument: eventDoc)
                return nil
            }
        } else {
            _ = try await db.runTransaction { transaction, _ in
                transaction.setData(["uid": uid, "createdAt": Timestamp(date: Date())], forDocument: upvoteDoc)
                transaction.updateData(["upvoteCount": FieldValue.increment(Int64(1))], forDocument: eventDoc)
                return nil
            }
            await ClientNotificationService.shared.notifyEventOwnerOfUpvote(eventId: eventId, actorUid: uid)
        }
    }

    func hasUpvoted(eventId: String, uid: String) async -> Bool {
        do {
            let snapshot = try await db.collection("events").document(eventId).collection("upvotes").document(uid).getDocument()
            return snapshot.exists
        } catch {
            return false
        }
    }

    func fetchUpvotedEventIDs(uid: String, eventIDs: [String]) async -> Set<String> {
        guard !eventIDs.isEmpty else { return [] }
        var result: Set<String> = []

        await withTaskGroup(of: String?.self) { group in
            for eventID in eventIDs {
                group.addTask {
                    do {
                        let snapshot = try await self.db.collection("events").document(eventID)
                            .collection("upvotes").document(uid)
                            .getDocument()
                        return snapshot.exists ? eventID : nil
                    } catch {
                        return nil
                    }
                }
            }

            for await maybeID in group {
                if let id = maybeID {
                    result.insert(id)
                }
            }
        }

        return result
    }

    // MARK: - Reporting
    func reportEvent(eventId: String, reporterUid: String, reason: String, description: String = "") async {
        do {
            let eventSnapshot = try await db.collection("events").document(eventId).getDocument()
            let eventData = eventSnapshot.data() ?? [:]
            let creatorUid = eventData["creatorUid"] as? String ?? ""
            if creatorUid == reporterUid {
                errorMessage = "You can't report your own event."
                HapticManager.notification(.warning)
                return
            }

            let reportRef = db.collection("reports").document()
            let caseRef = db.collection("moderation_cases").document()

            let reportData: [String: Any] = [
                "targetType": "EVENT",
                "targetId": eventId,
                "eventId": eventId,
                "targetOwnerUid": creatorUid,
                "targetTitle": eventData["title"] as? String ?? "Event",
                "targetPreview": eventData["description"] as? String ?? "",
                "reporterUid": reporterUid,
                "reason": reason,
                "description": description,
                "linkedCaseId": caseRef.documentID,
                "status": "OPEN",
                "createdAt": Timestamp(date: Date())
            ]

            let batch = db.batch()
            batch.setData(reportData, forDocument: reportRef)
            batch.setData([
                "reporterUid": reporterUid,
                "targetType": "EVENT",
                "targetId": eventId,
                "linkedReportId": reportRef.documentID,
                "reason": reason,
                "status": "OPEN",
                "createdAt": Timestamp(date: Date())
            ], forDocument: caseRef)
            try await batch.commit()

            successMessage = "Report submitted. Admin will review it shortly."
            HapticManager.notification(.success)
        } catch {
            errorMessage = "Failed to submit report. Please try again."
            HapticManager.notification(.error)
        }
    }
    
    // MARK: - Seed sample events into Firestore
    func seedSampleEvents() async throws {
        let snapshot = try await db.collection("events").limit(to: 1).getDocuments()
        guard snapshot.documents.isEmpty else {
            successMessage = "Events already exist in Firestore. Skipping seed."
            return
        }
        
        let sampleEvents = try Bundle.main.decode([SeedEvent].self, from: "events.json")
        
        for sample in sampleEvents {
            let firestoreEvent = FirestoreEvent(
                title: sample.title,
                description: sample.description ?? "",
                venue: sample.venue,
                date: sample.date,
                category: sample.category,
                creatorUid: "system",
                creatorEmail: "admin@campus.edu",
                createdAt: Timestamp(date: Date()),
                updatedAt: Timestamp(date: Date()),
                seats: sample.seats,
                tags: sample.tags,
                organizerName: sample.organizerName,
                organizerRole: sample.organizerRole,
                imageName: sample.imageName,
                status: EventLifecycleStatus.approved.rawValue,
                isApproved: true,
                upvoteCount: Int.random(in: 8...44),
                commentCount: Int.random(in: 2...26),
                replyCount: Int.random(in: 1...16),
                uniqueCommenterCount: Int.random(in: 2...80),
                trendingScore: Double.random(in: 3...75),
                discussionScore: Double.random(in: 1...50)
            )
            try db.collection("events").addDocument(from: firestoreEvent)
        }
        successMessage = "Seeded \(sampleEvents.count) sample events!"
        HapticManager.notification(.success)
    }
    
    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }

    func applySort(_ option: EventSortOption) {
        selectedSortOption = option
        allEvents = sortEvents(allEvents)
    }

    private func sortEvents(_ events: [FirestoreEvent]) -> [FirestoreEvent] {
        switch selectedSortOption {
        case .newest:
            return events.sorted { ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast) }
        case .trending:
            return events.sorted { (($0.upvoteCount ?? 0) + ($0.commentCount ?? 0)) > (($1.upvoteCount ?? 0) + ($1.commentCount ?? 0)) }
        case .mostUpvoted:
            return events.sorted { ($0.upvoteCount ?? 0) > ($1.upvoteCount ?? 0) }
        case .mostDiscussed:
            return events.sorted { ($0.commentCount ?? 0) > ($1.commentCount ?? 0) }
        case .nearestUpcoming:
            return events.sorted { $0.date < $1.date }
        }
    }

    private func mergeFeedEvents() {
        var byID: [String: FirestoreEvent] = [:]
        for event in approvedFeedEvents + legacyApprovedFeedEvents + ownFeedEvents {
            guard isExploreVisibleEvent(event) else { continue }
            guard let id = event.id else { continue }
            if let existing = byID[id] {
                let existingUpdated = existing.updatedAt?.dateValue() ?? existing.createdAt?.dateValue() ?? .distantPast
                let candidateUpdated = event.updatedAt?.dateValue() ?? event.createdAt?.dateValue() ?? .distantPast
                if candidateUpdated > existingUpdated {
                    byID[id] = event
                }
            } else {
                byID[id] = event
            }
        }

        allEvents = sortEvents(Array(byID.values))
        if approvedFeedLoaded && legacyApprovedFeedLoaded && ownFeedLoaded {
            isLoading = false
            if !allEvents.isEmpty {
                errorMessage = nil
            }
        } else {
            isLoading = true
        }
    }

    private func isSeededSystemEvent(_ event: FirestoreEvent) -> Bool {
        event.creatorUid == "system" || event.creatorEmail.lowercased() == "admin@campus.edu"
    }

    private func isExploreVisibleEvent(_ event: FirestoreEvent) -> Bool {
        event.lifecycleStatus == .approved &&
            event.removedByAdmin != true &&
            !isSeededSystemEvent(event) &&
            !isExpired(event)
    }

    private func updateFeedLoadingState() {
        isLoading = !(approvedFeedLoaded && legacyApprovedFeedLoaded && ownFeedLoaded)
    }

    private func isExpired(_ event: FirestoreEvent) -> Bool {
        guard let eventDate = DateFormatterHelper.date(from: event.date) else { return false }
        let expiresAt = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: eventDate)
        ) ?? eventDate
        return expiresAt <= Date()
    }
}

// MARK: - Seed Event (matches events.json structure)
private struct SeedEvent: Codable {
    let id: String
    let title: String
    let description: String?
    let venue: String
    let date: String
    let category: String
    let organizerName: String
    let organizerRole: String
    let imageName: String?
    let seats: Int?
    let tags: [String]?
}

enum FirestoreError: LocalizedError {
    case missingID
    
    var errorDescription: String? {
        switch self {
        case .missingID: return "Event ID is missing. Please try again."
        }
    }
}
