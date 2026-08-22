//
//  Post.swift
//  jez-blog
//

import Foundation
import SwiftData

@Model
final class Post {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var publishToWeb: Bool = false
    var webSlug: String?
    var tags: [String] = []

    /// The type chosen when the post was created. Used so an empty post opens
    /// in the editor the author asked for; content-derived inference takes over
    /// once the post actually has content.
    var intendedTypeRaw: String?

    @Relationship(deleteRule: .cascade) var blocks: [ContentBlock]?
    @Relationship(deleteRule: .cascade) var mediaAssets: [MediaAsset]?
    var folder: Folder?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        publishToWeb: Bool = false,
        webSlug: String? = nil,
        tags: [String] = [],
        intendedType: PostDisplayType? = nil,
        folder: Folder? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.publishToWeb = publishToWeb
        self.webSlug = webSlug
        self.tags = tags
        self.intendedTypeRaw = intendedType?.rawValue
        self.folder = folder
    }

    // MARK: - Derived content

    var intendedType: PostDisplayType? {
        get { intendedTypeRaw.flatMap(PostDisplayType.init(rawValue:)) }
        set { intendedTypeRaw = newValue?.rawValue }
    }

    /// Blocks in author order.
    var sortedBlocks: [ContentBlock] {
        (blocks ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Assets in author order.
    var sortedAssets: [MediaAsset] {
        (mediaAssets ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Determines the display type based on the post's content.
    ///
    /// Media leads: a picture or a clip decides the editor whether or not any
    /// words have been written, so text is always optional.
    var displayType: PostDisplayType {
        let blockCount = blocks?.count ?? 0
        let assets = mediaAssets ?? []

        if assets.contains(where: { $0.assetType == .linkPreview }) {
            return .linkCard
        }
        if assets.contains(where: { $0.assetType == .video }) {
            return .videoClip
        }

        let imageCount = assets.filter { $0.assetType == .image }.count

        if imageCount >= 2 {
            return .mediaArrangement
        }
        if imageCount == 1 {
            // A gallery that has only been half filled keeps its grid; one
            // picture with at most one caption reads as a photo post.
            if intendedType == .mediaArrangement { return .mediaArrangement }
            return blockCount <= 1 ? .shortWithImage : .mediaArrangement
        }

        // Nothing attached yet: keep the editor the author asked for.
        if let intended = intendedType, intended != .thread {
            return intended
        }
        return .thread
    }


    /// First line of text, used as a title in the timeline.
    var previewTitle: String {
        let firstText = sortedBlocks
            .first { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .content
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let firstText, let line = firstText.split(separator: "\n").first {
            return String(line)
        }
        if let link = sortedAssets.first(where: { $0.assetType == .linkPreview }) {
            return link.previewTitle ?? link.url?.host() ?? "Link"
        }

        // A wordless picture or clip is named by its alt text, else its file.
        if let media = sortedAssets.first(where: { $0.assetType == .image || $0.assetType == .video }) {
            if let alt = media.altText?.trimmingCharacters(in: .whitespacesAndNewlines), !alt.isEmpty {
                return alt
            }
            return media.displayName
        }

        return "Untitled \(displayType.label)"

    }

    /// Secondary preview text for the timeline.
    var previewExcerpt: String {
        let joined = sortedBlocks
            .map { $0.content.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if !joined.isEmpty { return joined }

        let mediaCount = mediaAssets?.count ?? 0
        return mediaCount > 0 ? "\(mediaCount) attachment\(mediaCount == 1 ? "" : "s")" : "Empty post"
    }

    /// Total characters typed across all blocks.
    var totalCharacterCount: Int {
        sortedBlocks.reduce(0) { $0 + $1.content.count }
    }

    /// Stamp the post as edited.
    func touch() {
        modifiedAt = Date()
    }

    /// Matches a free-text search query against title, body and tags.
    func matches(searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }

        if previewTitle.lowercased().contains(query) { return true }
        if previewExcerpt.lowercased().contains(query) { return true }
        if tags.contains(where: { $0.lowercased().contains(query) }) { return true }
        if sortedAssets.contains(where: { ($0.previewTitle ?? "").lowercased().contains(query) }) { return true }
        return false
    }
}
