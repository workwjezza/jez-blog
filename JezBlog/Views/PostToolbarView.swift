//
//  PostToolbarView.swift
//  jez-blog
//

import SwiftUI
import SwiftData

/// Publish toggle, timestamp and destructive actions for the open post.
struct PostToolbarView: View {
    @Bindable var post: Post
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false
    @State private var newTag: String = ""
    @State private var isAddingTag = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: Theme.componentSpacing) {
                Label(post.displayType.label, systemImage: post.displayType.symbolName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
                    .foregroundStyle(Theme.accent)

                Spacer()

                Text("Edited \(post.modifiedAt.relativeDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(post.modifiedAt.shortDescription)

                Toggle(isOn: Binding(
                    get: { post.publishToWeb },
                    set: { newValue in
                        withAnimation(Theme.spring) {
                            post.publishToWeb = newValue
                            if newValue, post.webSlug == nil {
                                post.webSlug = Self.slug(from: post.previewTitle)
                            }
                            post.touch()
                        }
                    }
                )) {
                    Text("Publish to Web")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete this post")
            }

            tagRow
        }
        .padding(.horizontal, Theme.sectionSpacing)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .confirmationDialog(
            "Delete this post?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Post", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the post and all of its blocks and media. This cannot be undone.")
        }
    }

    // MARK: - Tags

    private var tagRow: some View {
        HStack(spacing: 6) {
            ForEach(post.tags, id: \.self) { tag in
                TagChipView(tag: tag) {
                    withAnimation(Theme.spring) {
                        post.tags.removeAll { $0 == tag }
                        post.touch()
                    }
                }
            }

            if isAddingTag {
                TextField("tag", text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: 90)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.cardFill))
                    .onSubmit(commitTag)
            }

            Button {
                withAnimation(Theme.spring) {
                    if isAddingTag { commitTag() } else { isAddingTag = true }
                }
            } label: {
                Image(systemName: isAddingTag ? "checkmark.circle" : "plus.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(isAddingTag ? "Save tag" : "Add a tag")

            if post.publishToWeb, let slug = post.webSlug {
                Spacer()
                Text("/\(slug)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private func commitTag() {
        let trimmed = newTag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .lowercased()

        withAnimation(Theme.spring) {
            if !trimmed.isEmpty, !post.tags.contains(trimmed) {
                post.tags.append(trimmed)
                post.touch()
            }
            newTag = ""
            isAddingTag = false
        }
    }

    /// Turns a title into a URL-friendly slug.
    static func slug(from title: String) -> String {
        let allowed = title
            .lowercased()
            .map { character -> Character in
                character.isLetter || character.isNumber ? character : "-"
            }

        let collapsed = String(allowed)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")

        let trimmed = collapsed.isEmpty ? "untitled" : collapsed
        return String(trimmed.prefix(60))
    }
}
