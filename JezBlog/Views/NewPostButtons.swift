//
//  NewPostButtons.swift
//  jez-blog
//
//  One button per kind of post, so choosing is a glance rather than a menu.
//

import SwiftUI

struct NewPostButtons: View {
    var types: [PostDisplayType] = PostDisplayType.allCases

    /// Smallest tile width; the grid wraps into one or two rows to fit.
    var minimumWidth: CGFloat = 88

    let action: (PostDisplayType) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: 8)],
            spacing: 8
        ) {
            ForEach(types) { type in
                NewPostButton(type: type) { action(type) }
            }
        }
    }
}

// MARK: - Tile

private struct NewPostButton: View {
    let type: PostDisplayType
    let action: () -> Void

    @State private var isHovering = false

    private let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: type.symbolName)
                    .font(.system(size: 15, weight: .regular))

                Text(type.shortLabel)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 4)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .background(shape.fill(Theme.accent.opacity(isHovering ? 0.2 : 0.1)))
        .overlay(shape.strokeBorder(Theme.accent.opacity(isHovering ? 0.5 : 0.25), lineWidth: 1))
        .onHover { hovering in
            withAnimation(Theme.hover) { isHovering = hovering }
        }
        .help("New \(type.label)")
    }
}

#Preview {
    VStack(spacing: 24) {
        NewPostButtons { _ in }
            .frame(width: 226)

        NewPostButtons { _ in }
            .frame(width: 520)
    }
    .padding()
}
