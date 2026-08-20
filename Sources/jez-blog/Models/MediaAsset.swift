//
//  MediaAsset.swift
//  jez-blog
//
//  Media asset model for images, videos, and link previews
//

import Foundation
import SwiftData

@Model
class MediaAsset {
    var id: UUID
    var orderIndex: Int
    var assetType: AssetType
    var localPath: String?
    var cloudKitRecordID: String?
    var arrangement: MediaArrangement?
    
    // For link previews
    var url: URL?
    var previewTitle: String?
    var previewDescription: String?
    var previewImageURL: String?
    
    @Relationship(inverse: \Post.mediaAssets) var post: Post?
    
    init(id: UUID = UUID(), orderIndex: Int = 0, assetType: AssetType = .image, localPath: String? = nil, cloudKitRecordID: String? = nil, arrangement: MediaArrangement? = nil, url: URL? = nil, previewTitle: String? = nil, previewDescription: String? = nil, previewImageURL: String? = nil) {
        self.id = id
        self.orderIndex = orderIndex
        self.assetType = assetType
        self.localPath = localPath
        self.cloudKitRecordID = cloudKitRecordID
        self.arrangement = arrangement
        self.url = url
        self.previewTitle = previewTitle
        self.previewDescription = previewDescription
        self.previewImageURL = previewImageURL
    }
}
