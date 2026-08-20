//
//  PostPreviewRow.swift
//  jez-blog
//
//  Post preview row for timeline
//

import SwiftUI

struct PostPreviewRow: View {
    let post: Post
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Display type icon
                Image(systemName: iconForDisplayType(post.displayType))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Publish status
                if post.publishToWeb {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundStyle(.accentColor)
                }
                
                Spacer()
                
                // Timestamp
                Text(relativeTime(from: post.modifiedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Content preview
            Text(contentPreview)
                .font(.body)
                .fontDesign(.serif)
                .lineLimit(3)
                .foregroundStyle(.primary)
            
            // Tags
            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(post.tags, id: \.self) { tag in
                            TagChipView(tag: tag)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .background(Color.primary.opacity(0.02))
        .overlay(
            Rectangle()
                .frame(width: 3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.clear),
            alignment: .leading
        )
    }
    
    private var contentPreview: String {
        if let blocks = post.blocks, !blocks.isEmpty {
            let sortedBlocks = blocks.sorted { $0.orderIndex < $1.orderIndex }
            return sortedBlocks.first?.content ?? "Empty post"
        }
        
        if let mediaCount = post.mediaAssets?.count, mediaCount > 0 {
            return "\(mediaCount) media item\(mediaCount == 1 ? "" : "s")"
        }
        
        return "Empty post"
    }
    
    private func iconForDisplayType(_ type: PostDisplayType) -> String {
        switch type {
        case .thread: return "text.alignleft"
        case .mediaArrangement: return "square.grid.2x2"
        case .shortWithImage: return "photo.on.rectangle"
        case .videoClip: return "video"
        case .linkCard: return "link"
        }
    }
    
    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
