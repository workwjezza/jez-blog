//
//  TimelineView.swift
//  jez-blog
//

import SwiftUI

struct TimelineView: View {
    let posts: [Post]
    @Binding var selectedPost: Post?
    let collectionTitle: String
    let postCount: Int

    /// True for collections that read better as a wall of pictures.
    let allowsGallery: Bool
    @Binding var prefersGallery: Bool

    let onNewPost: (PostDisplayType) -> Void

    /// Files dropped here start a new post.
    let onImportFiles: ([URL]) -> Void

    private var showsGallery: Bool { allowsGallery && prefersGallery }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if posts.isEmpty {
                emptyState
            } else if showsGallery {
                MediaGalleryView(posts: posts, selectedPost: $selectedPost)
            } else {
                feed
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
        .animation(Theme.spring, value: showsGallery)
        .mediaDrop(
            kinds: MediaDropRouter.creationKinds,
            hint: "Drop files to start a post",
            onDrop: onImportFiles
        )
    }

    // MARK: - Content

    private var feed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(posts) { post in
                        PostPreviewRow(
                            post: post,
                            isSelected: selectedPost?.id == post.id
                        ) {
                            withAnimation(Theme.spring) {
                                selectedPost = post
                            }
                        }
                        .id(post.id)
                        .transition(Theme.cardTransition)
                    }
                }
                .padding(12)
                .animation(Theme.spring, value: posts.count)
            }
            .onKeyPress(.upArrow) {
                navigate(direction: -1, proxy: proxy)
                return .handled
            }
            .onKeyPress(.downArrow) {
                navigate(direction: 1, proxy: proxy)
                return .handled
            }
            .onKeyPress(.home) {
                navigateToFirst(proxy: proxy)
                return .handled
            }
            .onKeyPress(.end) {
                navigateToLast(proxy: proxy)
                return .handled
            }
        }
    }

    private func navigate(direction: Int, proxy: ScrollViewProxy) {
        guard !posts.isEmpty else { return }

        let currentIndex: Int
        if let selected = selectedPost,
           let index = posts.firstIndex(where: { $0.id == selected.id }) {
            currentIndex = index
        } else {
            currentIndex = direction > 0 ? -1 : posts.count
        }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < posts.count else { return }

        let newPost = posts[newIndex]
        withAnimation(Theme.spring) {
            selectedPost = newPost
        }
        proxy.scrollTo(newPost.id, anchor: .center)
    }

    private func navigateToFirst(proxy: ScrollViewProxy) {
        guard let first = posts.first else { return }
        withAnimation(Theme.spring) {
            selectedPost = first
        }
        proxy.scrollTo(first.id, anchor: .center)
    }

    private func navigateToLast(proxy: ScrollViewProxy) {
        guard let last = posts.last else { return }
        withAnimation(Theme.spring) {
            selectedPost = last
        }
        proxy.scrollTo(last.id, anchor: .center)
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "leaf",
            title: "No Posts",
            message: "Nothing planted here yet. Start one below, or drag files straight in.",
            accessory: AnyView(NewPostButtons(minimumWidth: 78, action: onNewPost))
        )
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(collectionTitle)
                    .font(.headline)
                    .fontDesign(.serif)

                // Show count only in timeline header, not in sidebar
                Text("\(postCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                if allowsGallery { layoutPicker }
            }
        }
        .padding(12)
    }

    private var layoutPicker: some View {
        Picker("Layout", selection: $prefersGallery) {
            Image(systemName: "square.grid.2x2").tag(true)
            Image(systemName: "list.bullet").tag(false)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("Show this collection as a gallery or as a list")
    }
}
