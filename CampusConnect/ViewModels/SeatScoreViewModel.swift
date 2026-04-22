// ============================================================
// SeatScoreViewModel.swift
// Tracks and scores seat availability for event listings
// ============================================================

import Foundation
import FirebaseFirestore

@MainActor
final class SeatScoreViewModel: ObservableObject {

    @Published var seatData: [String: SeatInfo] = [:]

    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]

    func startTracking(eventId: String) {
        guard listeners[eventId] == nil else { return }
        listeners[eventId] = db.collection("events").document(eventId)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor [weak self] in
                    guard let self, let data = snapshot?.data() else { return }
                    let max = data["maxSeats"] as? Int ?? 0
                    let rsvp = data["rsvpCount"] as? Int ?? 0
                    self.seatData[eventId] = SeatInfo(max: max, rsvpCount: rsvp)
                }
            }
    }

    func stopTracking(eventId: String) {
        listeners[eventId]?.remove()
        listeners.removeValue(forKey: eventId)
        seatData.removeValue(forKey: eventId)
    }

    func stopAll() {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
        seatData.removeAll()
    }

    func seatScore(for eventId: String) -> SeatAvailabilityLevel {
        guard let info = seatData[eventId] else { return .unknown }
        return info.availabilityLevel
    }
}

// MARK: - SeatInfo

struct SeatInfo {
    let max: Int
    let rsvpCount: Int

    var remaining: Int { max(0, max - rsvpCount) }
    var fillRatio: Double { max > 0 ? Double(rsvpCount) / Double(max) : 0 }

    var availabilityLevel: SeatAvailabilityLevel {
        if max == 0 { return .unlimited }
        if remaining == 0 { return .full }
        if fillRatio >= 0.85 { return .almostFull }
        if fillRatio >= 0.5  { return .limited }
        return .available
    }
}

enum SeatAvailabilityLevel {
    case available, limited, almostFull, full, unlimited, unknown

    var label: String {
        switch self {
        case .available:  return "Seats available"
        case .limited:    return "Limited seats"
        case .almostFull: return "Almost full"
        case .full:       return "Fully booked"
        case .unlimited:  return "Open event"
        case .unknown:    return ""
        }
    }

    var color: String {
        switch self {
        case .available:  return "green"
        case .limited:    return "yellow"
        case .almostFull: return "orange"
        case .full:       return "red"
        default:          return "gray"
        }
    }
}
