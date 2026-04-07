// ============================================================
// EventFilterView.swift
// Category filter sheet with interactive grid
// ============================================================

import SwiftUI

struct EventFilterView: View {
    @Binding var selectedCategory: String
    let categories: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filter by Category")
                        .font(.title3.weight(.bold))
                    Text("Choose a category to narrow down events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Constants.Design.horizontalPadding)
                
                // Category Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        categoryButton(category)
                    }
                }
                .padding(.horizontal, Constants.Design.horizontalPadding)
                
                Spacer()
                
                // Apply Button
                Button {
                    HapticManager.impact(.medium)
                    dismiss()
                } label: {
                    Text("Apply Filter")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: Constants.Design.buttonHeight)
                        .background(Constants.Colors.brandGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, Constants.Design.horizontalPadding)
                .padding(.bottom, 24)
            }
            .padding(.top, 20)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reset") {
                        selectedCategory = "All"
                        HapticManager.impact(.light)
                    }
                    .foregroundStyle(Constants.Colors.danger)
                }
            }
        }
    }
    
    private func categoryButton(_ category: String) -> some View {
        let isSelected = selectedCategory == category
        let color = category == "All" ? Constants.Colors.brandGradientStart : Constants.CategoryColors.color(for: category)
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedCategory = category
            }
            HapticManager.selection()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: category == "All" ? "square.grid.2x2.fill" : Constants.CategoryColors.icon(for: category))
                    .font(.subheadline)
                    .frame(width: 20)
                
                Text(category)
                    .font(.subheadline.weight(.medium))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(isSelected ? color.opacity(0.12) : Constants.Colors.cardBackground)
            .foregroundStyle(isSelected ? color : .primary)
            .clipShape(RoundedRectangle(cornerRadius: Constants.Design.smallCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Design.smallCornerRadius, style: .continuous)
                    .stroke(isSelected ? color.opacity(0.4) : Color(.systemGray5), lineWidth: 1.5)
            )
        }
    }
}
