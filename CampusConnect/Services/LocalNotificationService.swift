import Foundation
import UserNotifications

final class LocalNotificationService {
    static let shared = LocalNotificationService()
    private init() {}

    func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func scheduleReminder(eventId: String, title: String, triggerDate: Date) async {
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "CampusConnect Reminder"
        content.body = "\(title) is coming up soon."
        content.sound = .default
        content.userInfo = ["eventId": eventId]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "event_reminder_\(eventId)", content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Intentionally silent: UI handles the status via permission checks.
        }
    }

    func cancelReminder(eventId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["event_reminder_\(eventId)"])
    }
}
