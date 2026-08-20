//
//  Post.swift
//  jez-blog
//
//  Main post model with SwiftData
//

import Foundation
import SwiftData

@Model
class Post {
    var id: UUID
    var createdAt: Date
    var modifiedAt: Date
    var publishToWeb: Bool
    var webSlug: String?
    var tags: [String]
    
    @Relationship(deleteRule: .cascade) var blocks: [ContentBlock]?
    @Relationship(deleteRule: .cascade) var mediaAssets: [MediaAsset]?
    
    init(id: UUID = UUID(), createdAt: Date = Date(), modifiedAt: Date = Date(), publishToWeb: Bool = false, webSlug: String? = nil, tags: [String] = []) {
        self.id = id
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.publishToWeb = publishToWeb
        self.webSlug = webSlug
        self.tags = tags
    }
    
    // Computed property that determines display type based on content
    var displayType: PostDisplayType {
        let blockCount = blocks?.count ?? 0
        let mediaCount = mediaAssets?.count ?? 0
        
        // Check for link card (has link preview asset)
        if let assets = mediaAssets, assets.contains(where: { $0.assetType == .linkPreview }) {
            return .linkCard
        }
        
        // Check for video clip
        if mediaCount == 1, let asset = mediaAssets?.first, asset.assetType == .video {
            return .videoClip
        }
        
        // Check for media arrangement (multiple images)
        if mediaCount >= 2 && mediaCount <= 4 {
            let imageCount = mediaAssets?.filter { $0.assetType == .image }.count ?? 0
            if imageCount == mediaCount {
                return .mediaArrangement
            }
        }
        
        // Check for short with image (1 text block + 1 image)
        if blockCount == 1 && mediaCount == 1 {
            if let asset = mediaAssets?.first, asset.assetType == .image {
                return .shortWithImage
            }
        }
        
        // Default to thread for text-based posts
        return .thread
    }
}
