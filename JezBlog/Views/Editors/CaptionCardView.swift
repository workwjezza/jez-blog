//
//  CaptionCardView.swift
//  jez-blog
//
//  Words beside a picture or a clip — entirely optional. A photo can stand on
//  its own, so the caption is something you add, and can take away again.
//

import SwiftData
import SwiftUI

struct CaptionCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var post: Post

    var title: String = "Caption"
    var placeholder: String = "Say it in one breath…"
    var addLabel: String = "Add a caption"
    var addHint: String = "Optional — the picture can speak for itself"

    private var block: ContentBlock? { post.sortedBlocks.first }

    var body: some View {
        Group {
            if let block {
                editor(for: block)
            } else {
                addRow
            }
        }
        .animation(Theme.spring, value: block?.id)
    }

    // MARK: - Pieces

    private func editor(for block: ContentBlock) -> some View {
        let bindable = Bindable(block)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let limit = block.characterLimit {
                    Text("\(block.characterCount)/\(limit)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(block.isOverLimit ? .red : .secondary)
                }

                Button(role: .destructive) {
                    remove(block)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .help("Remove the caption")
            }

            TextEditor(text: bindable.content)
                .font(.body)
                .fontDesign(.serif)
                .scrollContentBackground(.hidden)
                .frame(minHeight: Theme.minBlockHeight)
                .overlay(alignment: .topLeading) {
                    if block.content.isEmpty {
                        Text(placeholder)
                            .font(.body)
                            .fontDesign(.serif)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: block.content) { _, _ in post.touch() }
        }
        .padding(Theme.cardPadding)
        .cardSurface()
        .transition(Theme.cardTransition)
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            Button(action: add) {
                Label(addLabel, systemImage: "text.bubble")
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)

            Text(addHint)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    private func add() {
        let block = ContentBlock(orderIndex: 0)
        modelContext.insert(block)

        withAnimation(Theme.spring) {
            var updated = post.blocks ?? []
            updated.append(block)
            post.blocks = updated
            post.touch()
        }
    }

    private func remove(_ block: ContentBlock) {
        withAnimation(Theme.spring) {
            post.blocks?.removeAll { $0.id == block.id }
            modelContext.delete(block)

            for (index, remaining) in post.sortedBlocks.enumerated() {
                remaining.orderIndex = index
            }
            post.touch()
        }
    }
}
