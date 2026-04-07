// ============================================================
// SeatScoreViewModel.swift
// State-driven seat/interest counter
// ============================================================

import Foundation

@MainActor
final class SeatScoreViewModel: ObservableObject {
    
    @Published var totalSeats: Int
    @Published var takenSeats: Int
    @Published var interestScore: Int
    
    init(totalSeats: Int = 100, takenSeats: Int = 0, interestScore: Int = 0) {
        self.totalSeats = totalSeats
        self.takenSeats = takenSeats
        self.interestScore = interestScore
    }
    
    var availableSeats: Int { max(0, totalSeats - takenSeats) }
    var isFull: Bool { availableSeats == 0 }
    
    var occupancyPercent: Double {
        guard totalSeats > 0 else { return 0 }
        return min(1.0, Double(takenSeats) / Double(totalSeats))
    }
    
    var occupancyLabel: String {
        "\(takenSeats)/\(totalSeats)"
    }
    
    var occupancyStatus: String {
        if isFull { return "Fully Booked" }
        if occupancyPercent > 0.8 { return "Almost Full" }
        if occupancyPercent > 0.5 { return "Filling Up" }
        return "Available"
    }
    
    func canRSVP() -> (canBook: Bool, reason: String) {
        if isFull { return (false, "Event is fully booked") }
        return (true, "\(availableSeats) seats remaining")
    }
    
    func incrementInterest() {
        interestScore += 1
        HapticManager.impact(.light)
    }
    
    func decrementInterest() {
        guard interestScore > 0 else { return }
        interestScore -= 1
        HapticManager.impact(.light)
    }
    
    func bookSeat() {
        guard !isFull else { return }
        takenSeats += 1
        interestScore += 1
    }
    
    func cancelSeat() {
        guard takenSeats > 0 else { return }
        takenSeats -= 1
    }
    
    func reset() {
        takenSeats = 0
        interestScore = 0
    }
}
