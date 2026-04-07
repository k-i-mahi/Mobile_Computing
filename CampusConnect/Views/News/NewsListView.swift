// ============================================================
// NewsListView.swift
// News feed, article rows, and article detail sheet
// ============================================================

import SwiftUI

// MARK: – News List
struct NewsListView: View {
    @StateObject private var vm = NewsViewModel()
    @State private var selectedArticle: NewsArticle?
    @State private var appeared = false

    var body: some View {
        Group {
            if vm.isLoading && vm.articles.isEmpty {
                LoadingView(message: "Fetching latest campus news…")
            } else if let error = vm.errorMessage, vm.articles.isEmpty {
                ErrorView(message: error, onRetry: {
                    Task { await vm.fetchNews() }
                })
            } else if vm.articles.isEmpty {
                EmptyStateView(
                    icon: "newspaper",
                    title: "No News",
                    message: "There are no campus news articles right now. Pull to refresh.",
                    buttonTitle: "Refresh",
                    action: { Task { await vm.fetchNews() } }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(Array(vm.articles.enumerated()), id: \.element.stableId) { index, article in
                            ArticleRowView(article: article)
                                .staggeredAppear(index: index, show: appeared)
                                .onTapGesture {
                                    HapticManager.impact(.light)
                                    selectedArticle = article
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable { await vm.fetchNews(forceRefresh: true) }
            }
        }
        .navigationTitle("Campus News")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let text = vm.lastRefreshedText {
                    Text(text)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            if vm.articles.isEmpty {
                await vm.fetchNews()
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) { appeared = true }
        }
        .sheet(item: $selectedArticle) { article in
            NewsDetailView(article: article)
        }
    }
}

// MARK: – Article Row
struct ArticleRowView: View {
    let article: NewsArticle

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Thumbnail
            if let url = article.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallbackThumb
                    default:
                        Rectangle()
                            .fill(.quaternary)
                            .overlay(ProgressView().scaleEffect(0.6))
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                fallbackThumb
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(article.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                if let desc = article.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    sourceBadge
                    Spacer()
                    Text(article.relativeDate)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Design.cornerRadius))
    }

    private var fallbackThumb: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Constants.Colors.accent.opacity(0.12))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "newspaper.fill")
                    .font(.title3)
                    .foregroundStyle(Constants.Colors.accent.opacity(0.5))
            )
    }

    @ViewBuilder
    private var sourceBadge: some View {
        Text(article.displaySource)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Constants.Colors.brandGradientStart)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Constants.Colors.brandGradientStart.opacity(0.1), in: Capsule())
    }
}

// MARK: – News Detail
struct NewsDetailView: View {
    let article: NewsArticle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero image
                    if let url = article.imageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
                                    .clipped()
                            default:
                                Rectangle()
                                    .fill(Constants.Colors.accent.opacity(0.1))
                                    .frame(height: 220)
                                    .overlay(ProgressView())
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        // Source & date
                        HStack {
                            Text(article.displaySource)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Constants.Colors.brandGradientStart.gradient, in: Capsule())

                            Spacer()
                            Text(article.relativeDate)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Title
                        Text(article.title)
                            .font(.title3.weight(.bold))

                        if let author = article.author, !author.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                                Text("By \(author)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }

                        Divider()

                        // Content
                        if let content = article.content ?? article.description {
                            Text(content)
                                .font(.body)
                                .lineSpacing(5)
                                .foregroundStyle(.primary.opacity(0.88))
                        }

                        // Link button
                        if let url = article.articleURL {
                            Link(destination: url) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.right.square.fill")
                                    Text("Read Full Article")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Constants.Colors.brandGradientStart.gradient, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}


