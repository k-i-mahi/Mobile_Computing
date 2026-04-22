import SwiftUI

struct RejectionFeedbackDetailView: View {
    let event: FirestoreEvent

    @State private var showResubmissionFlow = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(event.title)
                    .font(.title3.weight(.bold))

                statusCard
                feedbackCard

                Button {
                    showResubmissionFlow = true
                } label: {
                    Label("Open Resubmission Flow", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Constants.Colors.brandGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
        }
        .navigationTitle("Rejection Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showResubmissionFlow) {
            ResubmissionFlowView(event: event)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Status")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(event.lifecycleStatus.userFacingLabel)
                .font(.headline)
                .foregroundStyle(Constants.Colors.warning)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Admin Feedback")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(event.rejectionReason ?? "No feedback provided.")
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Constants.Colors.danger.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
