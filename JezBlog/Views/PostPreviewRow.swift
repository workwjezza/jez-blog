//
//  PostPreviewRow.swift
//  jez-blog
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// A single post as it appears in the timeline.
struct PostPreviewRow: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.orderIndex) var folders: [Folder]
    let post: Post
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovering = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var clickCount = 0
    @State private var clickTimer: Timer?
    @State private var isDragging = false
    @State private var showFolderPicker = false

    private var coverAsset: MediaAsset? {
        post.sortedAssets.first { $0.hasContent && ($0.assetType == .image || $0.assetType == .video) }
    }

    private var linkAsset: MediaAsset? {
        post.sortedAssets.first { $0.assetType == .linkPreview }
    }

    /// Responsive content type icons showing what's in the post
    private var contentTypeIcons: some View {
        let icons = post.contentTypeIcons
        return HStack(spacing: 4) {
            ForEach(icons, id: \.self) { iconName in
                Image(systemName: iconName)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    var body: some View {
        Button(action: handleClick) {
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail preview for media posts
                if let cover = coverAsset, let path = cover.localPath {
                    MediaThumbnailView(path: path, kind: cover.assetType, contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                } else if let link = linkAsset {
                    // Link preview thumbnail
                    linkThumbnail(for: link)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        // Responsive content type icons
                        contentTypeIcons

                        Spacer()

                        if post.publishToWeb {
                            Image(systemName: "globe")
                                .font(.caption2)
                                .foregroundStyle(Theme.accent)
                                .help("Published to web")
                        }

                        Text(post.createdAt.relativeDescription)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if isEditingTitle {
                        TextField("", text: $editedTitle, onCommit: saveTitle)
                            .font(.body.weight(.medium))
                            .fontDesign(.serif)
                            .textFieldStyle(.plain)
                            .onAppear { editedTitle = post.previewTitle }
                    } else {
                        Text(post.previewTitle)
                            .font(.body.weight(.medium))
                            .fontDesign(.serif)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                if post.previewExcerpt != post.previewTitle {
                    Text(post.previewExcerpt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                    if !post.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(post.tags.prefix(3), id: \.self) { tag in
                                TagChipView(tag: tag)
                            }
                            if post.tags.count > 3 {
                                Text("+\(post.tags.count - 3)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Content type summary
                    Text(post.contentTypeSummary)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.12) : (isHovering ? Theme.cardFillHover : Theme.cardFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? Theme.accent : Theme.hairline,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(
            color: .black.opacity(isHovering && !isSelected ? 0.10 : 0.04),
            radius: isHovering ? 8 : 3,
            x: 0,
            y: isHovering ? 3 : 1
        )
        .onHover { hovering in
            withAnimation(Theme.hover) { isHovering = hovering }
        }
        .opacity(isDragging ? 0.5 : 1.0)
        .draggable("post:\(post.id.uuidString)")
        .contextMenu {
            contextMenuContent
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerSheet(post: post, folders: folders)
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        // Add to Folder submenu
        Menu {
            ForEach(folders) { folder in
                Button {
                    post.folder = folder
                } label: {
                    HStack {
                        Text(folder.name)
                        if post.folder?.id == folder.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            if post.folder != nil {
                Divider()
                Button(role: .destructive) {
                    post.folder = nil
                } label: {
                    Label("Remove from folder", systemImage: "folder.badge.minus")
                }
            }
        } label: {
            Label("Add to Folder", systemImage: "folder")
        }

        Divider()

        // Rename action
        Button {
            isEditingTitle = true
            editedTitle = post.previewTitle
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        // Copy actions
        if let cover = coverAsset, let path = cover.localPath {
            Button {
                copyMediaToClipboard(path: path)
            } label: {
                Label("Copy Media", systemImage: "photo")
            }
        }

        Button {
            copyTextToClipboard(post.previewTitle)
        } label: {
            Label("Copy Title", systemImage: "doc.text")
        }

        if post.previewExcerpt != post.previewTitle {
            Button {
                copyTextToClipboard(post.previewExcerpt)
            } label: {
                Label("Copy Text", systemImage: "text.quote")
            }
        }
    }

    private func copyMediaToClipboard(path: String) {
        let url = URL(fileURLWithPath: path)
        if let image = NSImage(contentsOf: url) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        }
    }

    private func copyTextToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func handleClick() {
        clickCount += 1

        if clickCount == 1 {
            // Single click - select with smooth animation
            clickTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { _ in
                if clickCount == 1 {
                    withAnimation(Theme.selection) {
                        onSelect()
                    }
                }
                clickCount = 0
            }
        } else if clickCount == 2 {
            // Double click - pop out to window
            clickTimer?.invalidate()
            withAnimation(Theme.windowAppear) {
                PostPreviewWindowController.show(post: post, context: modelContext)
            }
            clickCount = 0
        }
    }

    private func saveTitle() {
        isEditingTitle = false

        // Update the alt text of the first media asset
        if let asset = coverAsset, !editedTitle.isEmpty {
            asset.altText = editedTitle
            post.touch()
        }
    }

    @ViewBuilder
    private func linkThumbnail(for asset: MediaAsset) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        if let string = asset.previewImageURL, let url = URL(string: string) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    ZStack {
                        Theme.cardFill
                        Image(systemName: "link").foregroundStyle(.secondary)
                    }
                default:
                    ZStack {
                        Theme.cardFill
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                            .fixedSize()
                    }
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
        } else {
            shape
                .fill(Theme.cardFill)
                .frame(width: 80, height: 80)
                .overlay(Image(systemName: "link").foregroundStyle(.secondary))
                .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }
}

// MARK: - Folder Picker Sheet

struct FolderPickerSheet: View {
    let post: Post
    let folders: [Folder]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(folders) { folder in
                    Button {
                        post.folder = folder
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text(folder.name)
                            Spacer()
                            if post.folder?.id == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if post.folder != nil {
                    Section {
                        Button(role: .destructive) {
                            post.folder = nil
                            dismiss()
                        } label: {
                            Label("Remove from folder", systemImage: "folder.badge.minus")
                        }
                    }
                }
            }
            .navigationTitle("Select Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
