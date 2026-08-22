//
//  ThreadComposerView.swift
//  jez-blog
//
//  The star of the show: composing a thread of text blocks.
//

import SwiftUI
import SwiftData

struct ThreadComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var post: Post

    @FocusState private var focusedBlockID: UUID?

    private var blocks: [ContentBlock] { post.sortedBlocks }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            header

            if blocks.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        BlockCardView(
                            block: block,
                            index: index,
                            total: blocks.count,
                            focusedBlockID: $focusedBlockID,
                            onMoveUp: { moveBlock(block, direction: -1) },
                            onMoveDown: { moveBlock(block, direction: 1) },
                            onDelete: { deleteBlock(block) },
                            onEdit: { post.touch() }
                        )
                        .transition(Theme.cardTransition)

                        // Insert-between affordance (and a trailing one at the end).
                        InsertBlockButton {
                            insertBlock(after: block)
                        }
                    }
                }
                .animation(Theme.spring, value: blocks.map(\.id))

                footer
            }
        }
    }

    // MARK: - Chrome

    private var header: some View {
        EditorHeader(
            title: "Thread",
            subtitle: summary
        ) {
            Button {
                addBlock()
            } label: {
                Label("Add Block", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .keyboardShortcut("\r", modifiers: [.command, .shift])
            .help("Add a block to the end of the thread (⇧⌘↩)")
        }
    }

    private var summary: String {
        let count = blocks.count
        let characters = post.totalCharacterCount
        let blockLabel = count == 1 ? "1 block" : "\(count) blocks"
        let overLimit = blocks.filter(\.isOverLimit).count

        if overLimit > 0 {
            return "\(blockLabel) · \(characters) characters · \(overLimit) over limit"
        }
        return "\(blockLabel) · \(characters) characters"
    }

    private var emptyState: some View {
        VStack(spacing: Theme.componentSpacing) {
            Text("This thread has no blocks yet.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                addBlock()
            } label: {
                Label("Add the first block", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .cardSurface()
    }

    private var footer: some View {
        HStack {
            Button {
                addBlock()
            } label: {
                Label("Add Block", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("Blocks post in order, top to bottom.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Block operations

    /// Appends a new block to the end of the thread.
    private func addBlock() {
        let block = ContentBlock(orderIndex: blocks.count)
        modelContext.insert(block)

        withAnimation(Theme.spring) {
            var updated = post.blocks ?? []
            updated.append(block)
            post.blocks = updated
            post.touch()
        }

        focusedBlockID = block.id
    }

    /// Inserts a new block directly after `block`, shifting the ones below it.
    private func insertBlock(after block: ContentBlock) {
        let insertionIndex = block.orderIndex + 1

        for existing in blocks where existing.orderIndex >= insertionIndex {
            existing.orderIndex += 1
        }

        let newBlock = ContentBlock(orderIndex: insertionIndex)
        modelContext.insert(newBlock)

        withAnimation(Theme.spring) {
            var updated = post.blocks ?? []
            updated.append(newBlock)
            post.blocks = updated
            post.touch()
        }

        focusedBlockID = newBlock.id
    }

    /// Removes a block and closes the gap in the ordering.
    private func deleteBlock(_ block: ContentBlock) {
        let removedID = block.id

        withAnimation(Theme.spring) {
            post.blocks?.removeAll { $0.id == removedID }
            modelContext.delete(block)
            reindex()
            post.touch()
        }

        if focusedBlockID == removedID {
            focusedBlockID = post.sortedBlocks.last?.id
        }
    }

    /// Swaps a block with its neighbour above (-1) or below (+1).
    private func moveBlock(_ block: ContentBlock, direction: Int) {
        let ordered = blocks
        guard let currentIndex = ordered.firstIndex(where: { $0.id == block.id }) else { return }

        let targetIndex = currentIndex + direction
        guard ordered.indices.contains(targetIndex) else { return }

        let neighbour = ordered[targetIndex]

        withAnimation(Theme.spring) {
            let temporary = block.orderIndex
            block.orderIndex = neighbour.orderIndex
            neighbour.orderIndex = temporary
            post.touch()
        }
    }

    /// Normalises order indices to 0..<n.
    private func reindex() {
        for (index, block) in post.sortedBlocks.enumerated() {
            block.orderIndex = index
        }
    }
}

// MARK: - Insert affordance

/// A slim "+" row that appears between blocks on hover.
private struct InsertBlockButton: View {
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 22)

                HStack(spacing: 6) {
                    line
                    Image(systemName: "plus.circle.fill")
                        .font(.callout)
                        .foregroundStyle(isHovering ? Theme.accent : Color.secondary.opacity(0.5))
                    line
                }
                .opacity(isHovering ? 1 : 0.35)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.hover) { isHovering = hovering }
        }
        .help("Insert a block here")
    }

    private var line: some View {
        Rectangle()
            .fill(isHovering ? Theme.accent.opacity(0.4) : Theme.hairline)
            .frame(height: 1)
    }
}
