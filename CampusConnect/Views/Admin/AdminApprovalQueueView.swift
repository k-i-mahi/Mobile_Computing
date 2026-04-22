import SwiftUI

struct AdminApprovalQueueView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var manager = FirestoreEventManager()
    @State private var rejectReason = ""
    @State private var rejectEvent: FirestoreEvent?

    var body: some View {
        Group {
            if manager.isLoading && manager.allEvents.isEmpty {
                LoadingView(message: "Loading approval queue...")
            } else if manager.allEvents.isEmpty {
                EmptyStateView(
                    icon: "checkmark.seal",
                    title: "Queue Empty",
                    message: "No pending events require review right now.",
                    buttonTitle: nil,
                    action: nil
                )
            } else {
                List {
                    ForEach(manager.allEvents, id: \.id) { event in
                        VStack(alignment: .leading, spacing: 10) {
                            NavigationLink {
                                EventDetailView(event: event.asEvent)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(event.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(event.creatorEmail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(event.shortDate)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: 10) {
                                Button {
                                    Task {
                                        guard let id = event.id,
                                              let adminUID = authViewModel.currentUID else { return }
                                        try? await manager.approveEvent(id: id, adminUID: adminUID)
                                    }
                                } label: {
                                    Label("Approve", systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Constants.Colors.success.opacity(0.14))
                                        .foregroundStyle(Constants.Colors.success)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    rejectEvent = event
                                } label: {
                                    Label("Reject", systemImage: "xmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Constants.Colors.warning.opacity(0.14))
                                        .foregroundStyle(Constants.Colors.warning)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                Task {
                                    guard let id = event.id,
                                          let adminUID = authViewModel.currentUID else { return }
                                    try? await manager.approveEvent(id: id, adminUID: adminUID)
                                }
                            } label: {
                                Label("Approve", systemImage: "checkmark")
                            }
                            .tint(Constants.Colors.success)

                            Button {
                                rejectEvent = event
                            } label: {
                                Label("Reject", systemImage: "xmark")
                            }
                            .tint(Constants.Colors.warning)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Approval Queue")
        .task { manager.startListeningPendingApprovals() }
        .onDisappear { manager.stopListeningAllEvents() }
        .overlay {
            if let msg = manager.successMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Constants.Colors.success.gradient, in: Capsule())
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4), value: msg)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        manager.clearSuccess()
                    }
                }
            }
        }
        .alert("Reject Event", isPresented: Binding(
            get: { rejectEvent != nil },
            set: { if !$0 { rejectEvent = nil } }
        )) {
            TextField("Reason", text: $rejectReason)
            Button("Cancel", role: .cancel) {
                rejectEvent = nil
                rejectReason = ""
            }
            Button("Reject", role: .destructive) {
                Task {
                    guard let event = rejectEvent,
                          let id = event.id,
                          let adminUID = authViewModel.currentUID,
                          !rejectReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    try? await manager.rejectEvent(id: id, reason: rejectReason, adminUID: adminUID)
                    rejectEvent = nil
                    rejectReason = ""
                }
            }
        }
    }
}
