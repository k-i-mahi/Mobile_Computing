import SwiftUI

struct NoticeBoardView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var vm = NoticeBoardViewModel()

    var body: some View {
        Group {
            if vm.isLoading && vm.items.isEmpty {
                LoadingView(message: "Syncing campus notices...")
            } else if vm.items.isEmpty {
                EmptyStateView(
                    icon: "megaphone",
                    title: "No Notices Yet",
                    message: "KUET notices will appear here when the sync job publishes updates.",
                    buttonTitle: nil,
                    action: nil
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.items) { item in
                            noticeCard(item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("Notice Board")
        .task {
            vm.startListening()
        }
        .onDisappear {
            vm.stopListening()
        }
        .overlay(alignment: .bottom) {
            if let message = vm.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Constants.Colors.warning.gradient, in: Capsule())
                    .padding(.bottom, 16)
            }
        }
    }

    @ViewBuilder
    private func noticeCard(_ item: NoticeBoardItem) -> some View {
        Button {
            guard let url = URL(string: item.originalUrl) else { return }
            openURL(url)
        } label: {
            noticeContent(item)
        }
        .buttonStyle(.plain)
    }

    private func noticeContent(_ item: NoticeBoardItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.sourceTypeText)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Constants.Colors.brandGradientStart.opacity(0.12))
                    .foregroundStyle(Constants.Colors.brandGradientStart)
                    .clipShape(Capsule())
                Spacer()
                Text(item.publishedDateText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if let sourceName = item.sourceName {
                Text(sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption2.weight(.semibold))
                Text(item.originalLinkText)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.forward.square")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Constants.Colors.brandGradientStart)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
