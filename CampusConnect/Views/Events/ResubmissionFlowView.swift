import SwiftUI

struct ResubmissionFlowView: View {
    let event: FirestoreEvent

    @State private var showEdit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resubmission Flow")
                .font(.title3.weight(.bold))

            step("1", "Read rejection feedback and verify all incorrect details.")
            step("2", "Fix title, host identity, venue, timeline, links, and description accuracy.")
            step("3", "Save updates and submit again. Status will return to Pending Approval.")

            Button {
                showEdit = true
            } label: {
                Label("Edit and Resubmit", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Constants.Colors.brandGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 6)

            Spacer()
        }
        .padding(16)
        .navigationTitle("Resubmit Event")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) {
            EditEventView(event: event)
        }
    }

    private func step(_ index: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(index)
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(Constants.Colors.brandGradientStart.opacity(0.14))
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
