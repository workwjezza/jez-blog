//
//  TagChipView.swift
//  jez-blog
//

import SwiftUI

/// Small capsule used to display a tag.
struct TagChipView: View {
    let tag: String
    var onRemove: (() -> Void)? = nil

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)

            if let onRemove, isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(Theme.accent.opacity(isHovering ? 0.22 : 0.14))
        )
        .foregroundStyle(Theme.accent)
        .onHover { hovering in
            withAnimation(Theme.hover) { isHovering = hovering }
        }
    }
}

#Preview {
    HStack {
        TagChipView(tag: "garden")
        TagChipView(tag: "film", onRemove: {})
    }
    .padding()
}
