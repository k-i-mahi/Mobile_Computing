// ============================================================
// NotificationService.swift
// Local notification scheduling and permission management
// ============================================================

import Foundation
import UserNotifications
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class NotificationService: ObservableObject {

    static let shared = NotificationService()

    @Published var permissionGranted: Bool = false

    private init() {}

    // MARK: - Permission

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            permissionGranted = granted
        } catch {
            permissionGranted = false
        }
    }

    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule Local Notification

    func scheduleEventReminder(eventId: String, title: String, date: Date, minutesBefore: Int = 30) {
        guard permissionGranted else { return }
        let trigger = buildTrigger(for: date, minutesBefore: minutesBefore)
        let content = UNMutableNotificationContent()
        content.title = "Event Reminder"
        content.body = "\(title) starts in \(minutesBefore) minutes."
        content.sound = .default
        content.userInfo = ["eventId": eventId]

        let request = UNNotificationRequest(
            identifier: "reminder-\(eventId)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelEventReminder(eventId: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["reminder-\(eventId)"])
    }

    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Push to Firestore (in-app notification)

    func pushInAppNotification(
        toUID: String,
        title: String,
        body: String,
        type: String,
        relatedEventId: String? = nil
    ) async {
        var data: [String: Any] = [
            "title": title,
            "body": body,
            "type": type,
            "isRead": false,
            "createdAt": Timestamp(date: Date())
        ]
        if let relatedEventId { data["relatedEventId"] = relatedEventId }

        let db = Firestore.firestore()
        try? await db.collection("users")
            .document(toUID)
            .collection("notifications")
            .addDocument(data: data)
    }

    func notifyRSVP(toUID: String, eventTitle: String, eventId: String) async {
        await pushInAppNotification(
            toUID: toUID,
            title: "RSVP Confirmed",
            body: "You're going to \(eventTitle).",
            type: "rsvp",
            relatedEventId: eventId
        )
    }

    func notifyEventUpdate(toUID: String, eventTitle: String, eventId: String) async {
        await pushInAppNotification(
            toUID: toUID,
            title: "Event Updated",
            body: "\(eventTitle) has been updated. Check the details.",
            type: "event_update",
            relatedEventId: eventId
        )
    }

    // MARK: - Helpers

    private func buildTrigger(for date: Date, minutesBefore: Int) -> UNCalendarNotificationTrigger {
        let fireDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: date) ?? date
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
