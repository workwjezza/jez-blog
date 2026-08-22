//
//  MediaAsset.swift
//  jez-blog
//

import Foundation
import SwiftData

@Model
final class MediaAsset {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var assetTypeRaw: String = AssetType.image.rawValue
    var localPath: String?
    var cloudKitRecordID: String?
    var arrangement: MediaArrangement?

    /// Alternative text, used by the exported web page.
    var altText: String?

    /// Cached duration in seconds for video and audio assets.
    var durationSeconds: Double?

    // For link previews
    var url: URL?
    var previewTitle: String?
    var previewDescription: String?
    var previewImageURL: String?

    @Relationship(inverse: \Post.mediaAssets) var post: Post?

    init(
        id: UUID = UUID(),
        orderIndex: Int = 0,
        assetType: AssetType = .image,
        localPath: String? = nil,
        cloudKitRecordID: String? = nil,
        arrangement: MediaArrangement? = nil,
        altText: String? = nil,
        durationSeconds: Double? = nil,
        url: URL? = nil,
        previewTitle: String? = nil,
        previewDescription: String? = nil,
        previewImageURL: String? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.assetTypeRaw = assetType.rawValue
        self.localPath = localPath
        self.cloudKitRecordID = cloudKitRecordID
        self.arrangement = arrangement
        self.altText = altText
        self.durationSeconds = durationSeconds
        self.url = url
        self.previewTitle = previewTitle
        self.previewDescription = previewDescription
        self.previewImageURL = previewImageURL
    }

    /// Strongly typed accessor for the persisted raw value.
    var assetType: AssetType {
        get { AssetType(rawValue: assetTypeRaw) ?? .image }
        set { assetTypeRaw = newValue.rawValue }
    }

    var hasContent: Bool {
        switch assetType {
        case .image, .video, .audio:
            return localPath != nil
        case .linkPreview:
            return url != nil
        }
    }

    var fileURL: URL? {
        guard let localPath else { return nil }
        return URL(fileURLWithPath: localPath)
    }

    var displayName: String {
        if let fileURL { return fileURL.lastPathComponent }
        if let url { return url.host() ?? url.absoluteString }
        return "Empty \(assetType.rawValue)"
    }

    /// Whether the file this asset points at still exists on disk.
    var fileExists: Bool {
        guard let localPath else { return false }
        return FileManager.default.fileExists(atPath: localPath)
    }

    /// "1:04" style duration, when known.
    var durationDescription: String? {
        guard let durationSeconds, durationSeconds > 0 else { return nil }
        let total = Int(durationSeconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Alt text with sensible fallbacks, used when exporting.
    var accessibleDescription: String {
        if let altText, !altText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return altText
        }
        return previewTitle ?? displayName
    }

    /// Marks this asset as the feature (double-width) tile of an arrangement.
    var isFeatureTile: Bool {
        get { (arrangement?.width ?? 1) > 1 }
        set { arrangement = MediaArrangement(x: 0, y: 0, width: newValue ? 2 : 1, height: 1) }
    }
}
