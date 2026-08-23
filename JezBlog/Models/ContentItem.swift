//
//  ContentItem.swift
//  jez-blog
//
//  Unified representation of any content within an adaptive post container.
//

import Foundation

/// A unified wrapper for content within an adaptive post.
/// This allows mixing text blocks, media, and links in any order.
enum ContentItem: Identifiable, Equatable {
    case block(ContentBlock)
    case asset(MediaAsset)
    
    var id: UUID {
        switch self {
        case .block(let block): return block.id
        case .asset(let asset): return asset.id
        }
    }
    
    var orderIndex: Int {
        get {
            switch self {
            case .block(let block): return block.orderIndex
            case .asset(let asset): return asset.orderIndex
            }
        }
        set {
            switch self {
            case .block(let block): block.orderIndex = newValue
            case .asset(let asset): asset.orderIndex = newValue
            }
        }
    }
    
    /// Returns the appropriate icon name for this content type
    var iconName: String {
        switch self {
        case .block:
            return "text.alignleft"
        case .asset(let asset):
            switch asset.assetType {
            case .image:
                return "photo"
            case .video:
                return "film"
            case .audio:
                return "waveform"
            case .linkPreview:
                return "link"
            }
        }
    }
    
    /// Returns a display label for this content type
    var typeLabel: String {
        switch self {
        case .block:
            return "Text"
        case .asset(let asset):
            switch asset.assetType {
            case .image: return "Image"
            case .video: return "Video"
            case .audio: return "Audio"
            case .linkPreview: return "Link"
            }
        }
    }
}

// MARK: - Post Extensions for Adaptive Content

extension Post {
    
    /// All content items (blocks and assets) merged and sorted by orderIndex.
    /// This provides a unified view of the post's content for adaptive containers.
    var contentItems: [ContentItem] {
        let blocks = (self.blocks ?? []).map(ContentItem.block)
        let assets = (self.mediaAssets ?? []).map(ContentItem.asset)
        return (blocks + assets).sorted { $0.orderIndex < $1.orderIndex }
    }
    
    /// Returns unique content type icons present in this post (max 4)
    var contentTypeIcons: [String] {
        var icons: [String] = []
        let items = contentItems
        
        // Check for text blocks
        if items.contains(where: { if case .block = $0 { return true } else { return false } }) {
            icons.append("text.alignleft")
        }
        
        // Check for media types
        let hasImage = items.contains { 
            if case .asset(let a) = $0, a.assetType == .image { return true }
            return false
        }
        let hasVideo = items.contains { 
            if case .asset(let a) = $0, a.assetType == .video { return true }
            return false
        }
        let hasAudio = items.contains { 
            if case .asset(let a) = $0, a.assetType == .audio { return true }
            return false
        }
        let hasLink = items.contains { 
            if case .asset(let a) = $0, a.assetType == .linkPreview { return true }
            return false
        }
        
        if hasImage { icons.append("photo") }
        if hasVideo { icons.append("film") }
        if hasAudio { icons.append("waveform") }
        if hasLink { icons.append("link") }
        
        return Array(icons.prefix(4))
    }
    
    /// Returns a summary of content types for display
    var contentTypeSummary: String {
        let items = contentItems
        let blockCount = items.filter { if case .block = $0 { return true } else { return false } }.count
        let imageCount = items.filter { if case .asset(let a) = $0, a.assetType == .image { return true } else { return false } }.count
        let videoCount = items.filter { if case .asset(let a) = $0, a.assetType == .video { return true } else { return false } }.count
        let audioCount = items.filter { if case .asset(let a) = $0, a.assetType == .audio { return true } else { return false } }.count
        let linkCount = items.filter { if case .asset(let a) = $0, a.assetType == .linkPreview { return true } else { return false } }.count
        
        var parts: [String] = []
        if blockCount > 0 { parts.append("\(blockCount) text") }
        if imageCount > 0 { parts.append("\(imageCount) image\(imageCount == 1 ? "" : "s")") }
        if videoCount > 0 { parts.append("\(videoCount) video\(videoCount == 1 ? "" : "s")") }
        if audioCount > 0 { parts.append("\(audioCount) audio") }
        if linkCount > 0 { parts.append("\(linkCount) link\(linkCount == 1 ? "" : "s")") }
        
        if parts.isEmpty { return "Empty post" }
        return parts.joined(separator: " · ")
    }
}
