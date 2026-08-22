//
//  SinglePostView.swift
//  jez-blog
//
//  One post, one thought: a single block of at most 280 characters. No blocks
//  to add, no pictures to arrange — just the one thing you wanted to say.
//

import SwiftData
import SwiftUI

struct SinglePostView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var post: Post

    /// The tweet-length limit a single post is held to.
    private let limit = PostDisplayType.singlePostCharacterLimit

    @FocusState private var isFocused: Bool

    /// A single post keeps everything in its first (and only) block.
    private var block: ContentBlock? { post.sortedBlocks.first }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            EditorHeader(title: "Post", subtitle: subtitle) {
                if let block, !block.content.isEmpty {
                    Button(role: .destructive) {
                        clear(block)
                    } label: {
                        Label("Clear", systemImage: "eraser")
                    }
                    .help("Empty this post and start again")
                }
            }

            if let block {
                card(block)
            } else {
                startRow
            }
        }
        .animation(Theme.spring, value: block?.id)
        .task { ensureBlock() }
    }

    // MARK: - Chrome

    private var subtitle: String {
        guard let block else { return "One thought, \(limit) characters" }

        let remaining = limit - block.characterCount
        if remaining < 0 {
            return "\(-remaining) character\(remaining == -1 ? "" : "s") over the \(limit) limit"
        }
        return "\(remaining) of \(limit) characters left"
    }

    private func card(_ block: ContentBlock) -> some View {
        let bindable = Bindable(block)

        return VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: bindable.content)
                .font(.title3)
                .fontDesign(.serif)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 160)
                .focused($isFocused)
                .overlay(alignment: .topLeading) {
                    if block.content.isEmpty {
                        Text("Say the one thing…")
                            .font(.title3)
                            .fontDesign(.serif)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: block.content) { _, _ in post.touch() }

            counter(block)
        }
        .padding(Theme.cardPadding)
        .cardSurface(isHighlighted: isFocused)
        .transition(Theme.cardTransition)
    }

    /// Characters used, and how close the post is to the limit.
    private func counter(_ block: ContentBlock) -> some View {
        let used = block.characterCount
        let isOver = used > limit
        let progress = min(Double(used) / Double(limit), 1)

        return HStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(isOver ? .red : Theme.accent)
                .frame(maxWidth: 140)

            if isOver {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            Text("\(used)/\(limit)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(isOver ? Color.red : .secondary)

            Spacer()

            Text("A post says one thing, once.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .help(isOver ? "Over the \(limit) character limit" : "Characters used")
    }

    private var startRow: some View {
        HStack(spacing: 10) {
            Button(action: addBlock) {
                Label("Start writing", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)

            Text("\(limit) characters, one block")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    /// A single post is never empty-handed: it always has its one block.
    private func ensureBlock() {
        guard post.sortedBlocks.isEmpty else { return }
        addBlock()
    }

    private func addBlock() {
        let block = ContentBlock(orderIndex: 0, characterLimit: limit)
        modelContext.insert(block)

        withAnimation(Theme.spring) {
            var updated = post.blocks ?? []
            updated.append(block)
            post.blocks = updated
            post.touch()
        }

        isFocused = true
    }

    private func clear(_ block: ContentBlock) {
        withAnimation(Theme.spring) {
            block.content = ""
            post.touch()
        }
        isFocused = true
    }
}

#Preview {
    SinglePostView(post: Post(intendedType: .singlePost))
        .padding()
        .frame(width: 700, height: 420)
        .modelContainer(for: [Post.self, ContentBlock.self, MediaAsset.self], inMemory: true)
}
