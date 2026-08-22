//
//  BlockCardView.swift
//  jez-blog
//
//  A single text block in a thread.
//

import SwiftUI
import SwiftData

struct BlockCardView: View {
    @Bindable var block: ContentBlock

    let index: Int
    let total: Int

    @FocusState.Binding var focusedBlockID: UUID?

    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void

    @State private var isHovering = false

    private var isFocused: Bool { focusedBlockID == block.id }
    private var canMoveUp: Bool { index > 0 }
    private var canMoveDown: Bool { index < total - 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            editor
        }
        .padding(Theme.cardPadding)
        .cardSurface(isHighlighted: isFocused, isHovering: isHovering)
        .onHover { hovering in
            withAnimation(Theme.hover) { isHovering = hovering }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("#\(index + 1)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(isFocused ? Theme.accent : Theme.accent.opacity(0.18))
                )
                .foregroundStyle(isFocused ? Color.white : Theme.accent)

            Spacer()

            characterCounter

            if isHovering || isFocused {
                controls
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
    }

    private var characterCounter: some View {
        Group {
            if let limit = block.characterLimit {
                HStack(spacing: 3) {
                    if block.isOverLimit {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                    }
                    Text("\(block.characterCount)/\(limit)")
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(block.isOverLimit ? Color.red : Color.secondary)
                .help(block.isOverLimit ? "Over the tweet-length limit" : "Characters used")
            } else {
                Text("\(block.characterCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 2) {
            Button(action: onMoveUp) {
                Image(systemName: "arrow.up")
            }
            .disabled(!canMoveUp)
            .help("Move block up")

            Button(action: onMoveDown) {
                Image(systemName: "arrow.down")
            }
            .disabled(!canMoveDown)
            .help("Move block down")

            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .help("Delete block")
        }
        .font(.caption)
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }

    // MARK: - Editor

    private var editor: some View {
        TextEditor(text: $block.content)
            .font(.body)
            .fontDesign(.serif)
            .lineSpacing(3)
            .scrollContentBackground(.hidden)
            .frame(minHeight: Theme.minBlockHeight)
            .focused($focusedBlockID, equals: block.id)
            .overlay(alignment: .topLeading) {
                if block.content.isEmpty {
                    Text(index == 0 ? "Start the thread…" : "Continue…")
                        .font(.body)
                        .fontDesign(.serif)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: block.content) { _, _ in
                onEdit()
            }
    }
}
