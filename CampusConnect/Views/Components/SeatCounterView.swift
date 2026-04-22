// ============================================================
// SeatCounterView.swift
// Animated seat occupancy and interest counter
// ============================================================

import SwiftUI

struct SeatCounterView: View {
    @ObservedObject var viewModel: SeatScoreViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Event Status", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(viewModel.occupancyStatus)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
            
            // Occupancy bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Seats taken")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.occupancyLabel)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 10)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: barGradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * viewModel.occupancyPercent), height: 10)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.takenSeats)
                    }
                }
                .frame(height: 10)
            }
            
            // Interest counter
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                        Text("\(viewModel.interestScore)")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .contentTransition(.numericText())
                    }
                }
                
                Spacer()
                
                InterestCounterChild(score: $viewModel.interestScore)
            }
            
            if viewModel.isFull {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text("This event is fully booked")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Constants.Colors.danger)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Constants.Colors.danger.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(18)
        .background(Constants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius, style: .continuous))
    }
    
    private var statusColor: Color {
        if viewModel.isFull { return Constants.Colors.danger }
        if viewModel.occupancyPercent > 0.8 { return Constants.Colors.warning }
        return Constants.Colors.success
    }
    
    private var barGradientColors: [Color] {
        if viewModel.isFull { return [Constants.Colors.danger, Constants.Colors.danger.opacity(0.7)] }
        if viewModel.occupancyPercent > 0.8 { return [Constants.Colors.warning, Constants.Colors.accent] }
        return [Constants.Colors.brandGradientStart, Constants.Colors.brandGradientEnd]
    }
}

// MARK: - Interest Counter Child
struct InterestCounterChild: View {
    @Binding var score: Int
    
    var body: some View {
        HStack(spacing: 14) {
            Button {
                guard score > 0 else { return }
                score -= 1
                HapticManager.impact(.light)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(score > 0 ? Constants.Colors.danger : Color(.systemGray4))
            }
            .disabled(score == 0)
            
            Button {
                score += 1
                HapticManager.impact(.light)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Constants.Colors.success)
            }
        }
    }
}
