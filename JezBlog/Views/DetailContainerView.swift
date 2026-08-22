//
//  DetailContainerView.swift
//  jez-blog
//
//  Chooses the right editor for the selected post — and takes files dropped
//  anywhere inside it, whatever editor is on screen.
//

import SwiftData
import SwiftUI

struct DetailContainerView: View {
    @Environment(\.modelContext) private var modelContext

    let post: Post?
    let onDelete: (Post) -> Void
    let onNewPost: (PostDisplayType) -> Void

    /// Files dropped with nothing open start a new post.
    let onImportFiles: ([URL]) -> Void

    @State private var dropMessage: String?
    @State private var messageTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let post {
                VStack(spacing: 0) {
                    PostToolbarView(post: post) {
                        onDelete(post)
                    }
                    Divider()

                    ScrollView {
                        editor(for: post)
                            .padding(Theme.sectionSpacing)
                            .frame(maxWidth: 780, alignment: .leading)
                            .frame(maxWidth: .infinity)
                    }
                }
                .id(post.id)
                .transition(.opacity)
            } else {
                emptyState
            }
        }
        .animation(Theme.spring, value: post?.id)
        .mediaDrop(
            kinds: MediaDropRouter.acceptedKinds(for: post),
            hint: MediaDropRouter.hint(for: post),
            onDrop: handleDrop
        )
        .overlay(alignment: .bottom) { toast }
        .animation(Theme.spring, value: dropMessage)
    }

    // MARK: - Pieces

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "square.and.pencil",
            title: "No Post Selected",
            message: "Pick something from the timeline, start a new post below, or drop files here.",
            accessory: AnyView(NewPostButtons(action: onNewPost))
        )
    }

    @ViewBuilder
    private var toast: some View {
        if let dropMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                Text(dropMessage)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            .padding(.bottom, 18)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func editor(for post: Post) -> some View {
        switch post.displayType {
        case .thread:
            ThreadComposerView(post: post)
        case .mediaArrangement:
            MediaArrangementView(post: post)
        case .shortWithImage:
            ShortImageView(post: post)
        case .videoClip:
            VideoClipView(post: post)
        case .linkCard:
            LinkCardView(post: post)
        case .singlePost:
            SinglePostView(post: post)
        }
    }

    // MARK: - Drops

    private func handleDrop(_ urls: [URL]) {
        guard let post else {
            onImportFiles(urls)
            return
        }
        show(MediaDropRouter.handle(urls, post: post, context: modelContext))
    }

    /// Shows a short-lived note about a drop that did not entirely work.
    private func show(_ message: String?) {
        messageTask?.cancel()
        dropMessage = message
        guard message != nil else { return }

        messageTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            dropMessage = nil
        }
    }
}
