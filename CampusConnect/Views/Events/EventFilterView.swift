// ============================================================
// EventFilterView.swift
// Category filter sheet for the event list
// ============================================================

import SwiftUI

struct EventFilterView: View {
    @Binding var selectedCategory: String
    let categories: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(categories, id: \.self) { category in
                Button {
                    HapticManager.impact(.light)
                    selectedCategory = category
                    dismiss()
                } label: {
                    HStack {
                        Text(category)
                            .foregroundStyle(.primary)
                        Spacer()
                        if category == selectedCategory {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Constants.Colors.brandGradientStart)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Filter by Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
