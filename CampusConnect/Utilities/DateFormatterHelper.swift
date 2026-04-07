// ============================================================
// DateFormatterHelper.swift
// Reusable date formatting with relative time support
// ============================================================

import Foundation

enum DateFormatterHelper {
    
    private static let inputFormats = [
        "yyyy-MM-dd",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "dd/MM/yyyy",
        "MM/dd/yyyy"
    ]
    
    // MARK: - Full display: "June 15, 2025"
    static func display(from string: String) -> String? {
        guard let date = date(from: string) else { return nil }
        let output = DateFormatter()
        output.dateStyle = .long
        output.timeStyle = .none
        return output.string(from: date)
    }
    
    // MARK: - Short display: "Jun 15, 2025"
    static func shortDisplay(from string: String) -> String? {
        guard let date = date(from: string) else { return nil }
        let output = DateFormatter()
        output.dateStyle = .medium
        output.timeStyle = .none
        return output.string(from: date)
    }
    
    // MARK: - Relative: "in 3 days", "2 weeks ago"
    static func relativeDisplay(from string: String) -> String? {
        guard let date = date(from: string) else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Day and month: "15\nJUN"
    static func dayMonth(from string: String) -> (day: String, month: String)? {
        guard let date = date(from: string) else { return nil }
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "d"
        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "MMM"
        return (dayFmt.string(from: date), monthFmt.string(from: date).uppercased())
    }
    
    // MARK: - Parse string to Date
    static func date(from string: String) -> Date? {
        for format in inputFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
    
    // MARK: - Date to string
    static func string(from date: Date, format: String = "yyyy-MM-dd") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    // MARK: - Check if date is upcoming
    static func isUpcoming(_ string: String) -> Bool {
        guard let date = date(from: string) else { return false }
        return date > Date()
    }
    
    // MARK: - Days until event
    static func daysUntil(_ string: String) -> Int? {
        guard let date = date(from: string) else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date))
        return components.day
    }
}
