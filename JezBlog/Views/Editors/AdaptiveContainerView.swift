//
//  AdaptiveContainerView.swift
//  jez-blog
//
//  A responsive, adaptive container that can hold any mix of content types.
//  Supports drag-and-drop reordering and dynamic content addition.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AdaptiveContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var post: Post
    
    @FocusState private var focusedBlockID: UUID?
    @State private var isDraggingItem: UUID?
    @State private var dropTargetIndex: Int?
    @State private var isHoveringBlankSpace = false
    @State private var newBlockText = ""
    @State private var isEditingNewBlock = false
    
    /// Maximum number of images in a post
    private let maxImages = 25
    
    private var sortedBlocks: [ContentBlock] { post.sortedBlocks }
    private var sortedAssets: [MediaAsset] { post.sortedAssets }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Blank space at top - click to type
                    blankSpaceAtTop
                    
                    // Content items - blocks and assets interleaved
                    contentList
                    
                    // Bottom spacer for drop target
                    if sortedBlocks.isEmpty && sortedAssets.isEmpty {
                        emptyStateDropZone
                    }
                    
                    // Bottom padding
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, Theme.sectionSpacing)
                .padding(.top, Theme.sectionSpacing)
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.2))
    }
    
    // MARK: - Top Blank Space (Click to Type)
    
    private var blankSpaceAtTop: some View {
        VStack(spacing: 0) {
            if isEditingNewBlock {
                // Active text input at top
                newBlockEditor
            } else {
                // Clickable blank space
                Button(action: startNewBlockAtTop) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                            .fill(isHoveringBlankSpace ? Theme.accent.opacity(0.08) : Color.clear)
                            .frame(minHeight: 60)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                            Text("Click to start typing, or drop files here")
                                .font(.body)
                        }
                        .foregroundStyle(isHoveringBlankSpace ? Theme.accent : Color.secondary)
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(Theme.hover) { isHoveringBlankSpace = hovering }
                }
                .dropDestination(for: URL.self) { urls, location in
                    handleDrop(urls, atIndex: 0)
                } isTargeted: { isTargeted in
                    isHoveringBlankSpace = isTargeted
                }
            }
        }
    }
    
    private var newBlockEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("New text block")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Cancel") {
                    isEditingNewBlock = false
                    newBlockText = ""
                }
                .buttonStyle(.link)
                
                Button("Add") {
                    commitNewBlockAtTop()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(newBlockText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            TextEditor(text: $newBlockText)
                .font(.body)
                .fontDesign(.serif)
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
        }
        .padding(Theme.cardPadding)
        .cardSurface(isHighlighted: true)
        .transition(Theme.cardTransition)
    }
    
    // MARK: - Content List
    
    private var contentList: some View {
        let allItems = mergeItems()
        
        return LazyVStack(spacing: Theme.componentSpacing) {
            ForEach(Array(allItems.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 0) {
                    // Drop indicator above item
                    if dropTargetIndex == index && isDraggingItem != nil {
                        dropIndicator
                    }
                    
                    // Content item
                    itemView(for: item, index: index, total: allItems.count)
                        .id(item.id)
                        .opacity(isDraggingItem == item.id ? 0.5 : 1.0)
                        .draggable(item.id.uuidString) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.accent.opacity(0.3))
                                .frame(width: 200, height: 60)
                                .overlay(Image(systemName: item.icon).foregroundStyle(Theme.accent))
                        }
                        .dropDestination(for: String.self) { itemIDs, location in
                            guard let draggedIDString = itemIDs.first,
                                  let draggedID = UUID(uuidString: draggedIDString),
                                  draggedID != item.id else { return false }
                            moveItem(withID: draggedID, toIndex: index)
                            return true
                        } isTargeted: { isTargeted in
                            dropTargetIndex = isTargeted ? index : nil
                        }
                        
                    // Insert button between items
                    if index < allItems.count - 1 {
                        InsertContentButton {
                            insertNewContent(after: index)
                        }
                    }
                }
            }
            
            // Drop indicator at end
            if dropTargetIndex == allItems.count && isDraggingItem != nil {
                dropIndicator
            }
        }
        .animation(Theme.spring, value: allItems.count)
        .animation(Theme.spring, value: dropTargetIndex)
    }
    
    private var dropIndicator: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Theme.accent)
            .frame(height: 3)
            .padding(.horizontal, 20)
            .transition(.opacity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateDropZone: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("This post is empty")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Drop images, videos, or links here, or click above to start typing")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
        .cardSurface()
        .dropDestination(for: URL.self) { urls, location in
            handleDrop(urls, atIndex: 0)
        } isTargeted: { _ in }
    }
    
    // MARK: - Item Helpers
    
    private struct ItemInfo: Identifiable {
        let id: UUID
        let icon: String
        let type: ItemType
        let orderIndex: Int
        
        enum ItemType {
            case block(ContentBlock)
            case asset(MediaAsset)
        }
    }
    
    private func mergeItems() -> [ItemInfo] {
        var items: [ItemInfo] = []
        
        for block in sortedBlocks {
            items.append(ItemInfo(
                id: block.id,
                icon: "text.alignleft",
                type: .block(block),
                orderIndex: block.orderIndex
            ))
        }
        
        for asset in sortedAssets {
            let icon: String = switch asset.assetType {
            case .image: "photo"
            case .video: "film"
            case .audio: "waveform"
            case .linkPreview: "link"
            }
            items.append(ItemInfo(
                id: asset.id,
                icon: icon,
                type: .asset(asset),
                orderIndex: asset.orderIndex
            ))
        }
        
        return items.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    @ViewBuilder
    private func itemView(for item: ItemInfo, index: Int, total: Int) -> some View {
        switch item.type {
        case .block(let block):
            AdaptiveBlockCard(
                block: block,
                index: index,
                total: total,
                focusedBlockID: $focusedBlockID,
                onMoveUp: { moveItem(at: index, direction: -1) },
                onMoveDown: { moveItem(at: index, direction: 1) },
                onDelete: { deleteItem(at: index) }
            )
        case .asset(let asset):
            AdaptiveAssetCard(
                asset: asset,
                index: index,
                total: total,
                onMoveUp: { moveItem(at: index, direction: -1) },
                onMoveDown: { moveItem(at: index, direction: 1) },
                onDelete: { deleteItem(at: index) }
            )
        }
    }
    
    // MARK: - Actions
    
    private func startNewBlockAtTop() {
        withAnimation(Theme.spring) { isEditingNewBlock = true }
    }
    
    private func commitNewBlockAtTop() {
        let trimmed = newBlockText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Shift all existing content down
        for block in sortedBlocks { block.orderIndex += 1 }
        for asset in sortedAssets { asset.orderIndex += 1 }
        
        let block = ContentBlock(orderIndex: 0, content: trimmed)
        modelContext.insert(block)
        
        withAnimation(Theme.spring) {
            var updated = post.blocks ?? []
            updated.append(block)
            post.blocks = updated
            post.touch()
            newBlockText = ""
            isEditingNewBlock = false
            focusedBlockID = block.id
        }
    }
    
    private func insertNewContent(after index: Int) {
        let insertionIndex = index + 1
        
        // Shift items after insertion point
        for block in sortedBlocks where block.orderIndex >= insertionIndex {
            block.orderIndex += 1
        }
        for asset in sortedAssets where asset.orderIndex >= insertionIndex {
            asset.orderIndex += 1
        }
        
        let block = ContentBlock(orderIndex: insertionIndex)
        modelContext.insert(block)
        
        withAnimation(Theme.spring) {
            var updated = post.blocks ?? []
            updated.append(block)
            post.blocks = updated
            post.touch()
            focusedBlockID = block.id
        }
    }
    
    private func handleDrop(_ urls: [URL], atIndex index: Int) -> Bool {
        let editor = MediaEditor(post: post, context: modelContext)
        var importedCount = 0
        
        for url in urls {
            guard let kind = MediaStore.assetType(for: url) else { continue }
            
            if kind == .image && sortedAssets.filter({ $0.assetType == .image }).count >= maxImages {
                continue
            }
            
            let targetIndex = index + importedCount
            
            // Shift existing items
            for block in sortedBlocks where block.orderIndex >= targetIndex {
                block.orderIndex += 1
            }
            for asset in sortedAssets where asset.orderIndex >= targetIndex {
                asset.orderIndex += 1
            }
            
            do {
                let path = try MediaStore.importFile(at: url, expecting: kind)
                let asset = MediaAsset(orderIndex: targetIndex, assetType: kind, localPath: path)
                modelContext.insert(asset)
                
                var updated = post.mediaAssets ?? []
                updated.append(asset)
                post.mediaAssets = updated
                importedCount += 1
            } catch {
                print("Failed to import: \(error)")
            }
        }
        
        if importedCount > 0 { post.touch() }
        return importedCount > 0
    }
    
    private func moveItem(at index: Int, direction: Int) {
        let items = mergeItems()
        guard index + direction >= 0 && index + direction < items.count else { return }
        
        let current = items[index]
        let target = items[index + direction]
        
        withAnimation(Theme.spring) {
            let temp = current.orderIndex
            
            switch current.type {
            case .block(let b): b.orderIndex = target.orderIndex
            case .asset(let a): a.orderIndex = target.orderIndex
            }
            
            switch target.type {
            case .block(let b): b.orderIndex = temp
            case .asset(let a): a.orderIndex = temp
            }
            
            post.touch()
        }
    }
    
    private func moveItem(withID id: UUID, toIndex targetIndex: Int) {
        let items = mergeItems()
        guard let currentIndex = items.firstIndex(where: { $0.id == id }) else { return }
        
        let item = items[currentIndex]
        
        withAnimation(Theme.spring) {
            if currentIndex < targetIndex {
                for i in (currentIndex + 1)...targetIndex {
                    let idx = items[i].orderIndex - 1
                    switch items[i].type {
                    case .block(let b): b.orderIndex = idx
                    case .asset(let a): a.orderIndex = idx
                    }
                }
            } else {
                for i in targetIndex..<currentIndex {
                    let idx = items[i].orderIndex + 1
                    switch items[i].type {
                    case .block(let b): b.orderIndex = idx
                    case .asset(let a): a.orderIndex = idx
                    }
                }
            }
            
            switch item.type {
            case .block(let b): b.orderIndex = targetIndex
            case .asset(let a): a.orderIndex = targetIndex
            }
            
            post.touch()
        }
    }
    
    private func deleteItem(at index: Int) {
        let items = mergeItems()
        guard index < items.count else { return }
        
        let item = items[index]
        
        withAnimation(Theme.spring) {
            switch item.type {
            case .block(let block):
                post.blocks?.removeAll { $0.id == block.id }
                modelContext.delete(block)
            case .asset(let asset):
                MediaStore.removeFile(atPath: asset.localPath)
                post.mediaAssets?.removeAll { $0.id == asset.id }
                modelContext.delete(asset)
            }
            
            // Reindex remaining items
            for (i, remaining) in items.enumerated() where i > index {
                switch remaining.type {
                case .block(let b): b.orderIndex = i - 1
                case .asset(let a): a.orderIndex = i - 1
                }
            }
            
            post.touch()
        }
        
        if focusedBlockID == item.id {
            focusedBlockID = nil
        }
    }
}

// MARK: - Insert Button

private struct InsertContentButton: View {
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle().fill(Color.clear).frame(height: 24)
                HStack(spacing: 8) {
                    line
                    Image(systemName: "plus.circle.fill")
                        .font(.callout)
                        .foregroundStyle(isHovering ? Theme.accent : Color.secondary.opacity(0.5))
                    line
                }
                .opacity(isHovering ? 1 : 0.25)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(Theme.hover) { isHovering = hovering } }
        .help("Insert content here")
    }
    
    private var line: some View {
        Rectangle()
            .fill(isHovering ? Theme.accent.opacity(0.4) : Theme.hairline)
            .frame(height: 1)
    }
}

// MARK: - Adaptive Block Card

struct AdaptiveBlockCard: View {
    @Bindable var block: ContentBlock
    let index: Int
    let total: Int
    @FocusState.Binding var focusedBlockID: UUID?
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    private var isFocused: Bool { focusedBlockID == block.id }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft").font(.caption).foregroundStyle(.secondary)
                Text("Text").font(.caption).foregroundStyle(.secondary)
                Spacer()
                
                if let limit = block.characterLimit {
                    HStack(spacing: 3) {
                        if block.isOverLimit {
                            Image(systemName: "exclamationmark.triangle.fill").font(.caption2).foregroundStyle(.red)
                        }
                        Text("\(block.characterCount)/\(limit)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(block.isOverLimit ? .red : .secondary)
                    }
                }
                
                if isHovering || isFocused {
                    HStack(spacing: 2) {
                        Button(action: onMoveUp) { Image(systemName: "arrow.up") }.disabled(index == 0)
                        Button(action: onMoveDown) { Image(systemName: "arrow.down") }.disabled(index == total - 1)
                        Button(action: onDelete) { Image(systemName: "trash") }
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                }
            }
            
            TextEditor(text: $block.content)
                .font(.body)
                .fontDesign(.serif)
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .frame(minHeight: Theme.minBlockHeight)
                .focused($focusedBlockID, equals: block.id)
                .overlay(alignment: .topLeading) {
                    if block.content.isEmpty {
                        Text("Type something...")
                            .font(.body)
                            .fontDesign(.serif)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(Theme.cardPadding)
        .cardSurface(isHighlighted: isFocused, isHovering: isHovering)
        .onHover { hovering in withAnimation(Theme.hover) { isHovering = hovering } }
    }
}

// MARK: - Adaptive Asset Card

struct AdaptiveAssetCard: View {
    @Bindable var asset: MediaAsset
    let index: Int
    let total: Int
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    @State private var altText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: assetIcon).font(.caption).foregroundStyle(.secondary)
                Text(assetLabel).font(.caption).foregroundStyle(.secondary)
                Spacer()
                
                if isHovering {
                    HStack(spacing: 2) {
                        Button(action: onMoveUp) { Image(systemName: "arrow.up") }.disabled(index == 0)
                        Button(action: onMoveDown) { Image(systemName: "arrow.down") }.disabled(index == total - 1)
                        Button(action: onDelete) { Image(systemName: "trash") }
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                }
            }
            
            contentView
            
            if asset.assetType == .image || asset.assetType == .video {
                TextField("Caption or alt text...", text: Binding(
                    get: { asset.altText ?? "" },
                    set: { asset.altText = $0.isEmpty ? nil : $0 }
                ))
                .font(.callout)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(Theme.cardPadding)
        .cardSurface(isHovering: isHovering)
        .onHover { hovering in withAnimation(Theme.hover) { isHovering = hovering } }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch asset.assetType {
        case .image:
            if let path = asset.localPath {
                MediaThumbnailView(path: path, kind: .image, contentMode: .fit)
                    .frame(maxHeight: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                placeholder(icon: "photo", text: "No image")
            }
        case .video:
            if let path = asset.localPath {
                VideoPlayerView(videoPath: path)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                placeholder(icon: "film", text: "No video")
            }
        case .audio:
            placeholder(icon: "waveform", text: "Audio: \(asset.displayName)")
        case .linkPreview:
            LinkPreviewCard(asset: asset)
        }
    }
    
    private func placeholder(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Theme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private var assetIcon: String {
        switch asset.assetType {
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "waveform"
        case .linkPreview: return "link"
        }
    }
    
    private var assetLabel: String {
        switch asset.assetType {
        case .image: return "Image"
        case .video: return "Video"
        case .audio: return "Audio"
        case .linkPreview: return "Link"
        }
    }
}

// MARK: - Link Preview Card

struct LinkPreviewCard: View {
    let asset: MediaAsset
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = asset.previewImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                    case .failure: Color.gray.opacity(0.2)
                    default: Color.gray.opacity(0.1)
                    }
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let title = asset.previewTitle {
                    Text(title).font(.callout.weight(.medium)).lineLimit(2)
                }
                if let desc = asset.previewDescription {
                    Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
                if let url = asset.url {
                    Text(url.host() ?? url.absoluteString).font(.caption2).foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(12)
        .background(Theme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let videoPath: String
    
    var body: some View {
        ZStack {
            Color.black
            Image(systemName: "play.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 4)
        }
    }
}
