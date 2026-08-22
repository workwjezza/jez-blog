//
//  Enums.swift
//  jez-blog
//
//  Shared value types used across the media garden.
//

import Foundation

/// The shape a post takes when it is displayed.
///
/// A post's type is inferred from its content (see `Post.displayType`), but a
/// freshly created post can declare an intended type so the editor opens in the
/// right mode before any content exists.
enum PostDisplayType: String, Codable, CaseIterable, Identifiable {
    case thread             // 2-4 text blocks
    case mediaArrangement   // up to 25 images in a grid
    case shortWithImage     // 1 text block + 1 image
    case videoClip          // single video
    case linkCard           // URL with preview
    case singlePost         // one thought, 280 characters

    var id: String { rawValue }

    /// The tweet-length limit a single post is held to.
    static let singlePostCharacterLimit = 280

    var label: String {
        switch self {
        case .thread:           return "Thread"
        case .mediaArrangement: return "Media Arrangement"
        case .shortWithImage:   return "Photo"

        case .videoClip:        return "Video Clip"
        case .linkCard:         return "Link Card"
        case .singlePost:       return "Post"
        }
    }

    /// A one-word label, for buttons that sit side by side.
    var shortLabel: String {
        switch self {
        case .thread:           return "Thread"
        case .mediaArrangement: return "Gallery"
        case .shortWithImage:   return "Photo"
        case .videoClip:        return "Video"
        case .linkCard:         return "Link"
        case .singlePost:       return "Post"
        }
    }

    var symbolName: String {
        switch self {
        case .thread:           return "text.alignleft"
        case .mediaArrangement: return "square.grid.2x2"
        case .shortWithImage:   return "photo.on.rectangle.angled"
        case .videoClip:        return "film"
        case .linkCard:         return "link"
        case .singlePost:       return "text.bubble"
        }
    }

    /// Posts made of words alone — no picture, no clip, no link.
    var isTextOnly: Bool {
        self == .thread || self == .singlePost
    }
}


/// The kind of content a single block holds.
enum BlockType: String, Codable, CaseIterable {
    case text, embed, spacer
}

/// The kind of media an asset represents.
enum AssetType: String, Codable, CaseIterable {
    case image, video, audio, linkPreview
}

/// Where a media asset sits inside a 2x2 arrangement grid.
struct MediaArrangement: Codable, Equatable, Hashable {
    var x: Int      // 0-1 grid position
    var y: Int      // 0-1 grid position
    var width: Int  // 1-2 spans
    var height: Int // 1-2 spans

    init(x: Int = 0, y: Int = 0, width: Int = 1, height: Int = 1) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Sidebar collections used to filter the timeline.
///
/// Named `PostCollection` rather than `Collection` so it does not shadow the
/// standard library's `Collection` protocol inside this module.
enum PostCollection: String, Codable, CaseIterable, Identifiable, Hashable {
    case all, threads, media, links, unpublished

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:          return "All Posts"
        case .threads:      return "Threads"
        case .media:        return "Media"
        case .links:        return "Links"
        case .unpublished:  return "Unpublished"
        }
    }

    var symbolName: String {
        switch self {
        case .all:          return "square.stack"
        case .threads:      return "text.alignleft"
        case .media:        return "photo.on.rectangle"
        case .links:        return "link"
        case .unpublished:  return "tray"
        }
    }

    /// Whether a post belongs in this collection.
    func contains(_ post: Post) -> Bool {
        switch self {
        case .all:
            return true
        case .threads:
            // Words-only posts live together: threads and single posts alike.
            return post.displayType.isTextOnly
        case .media:
            let mediaTypes: [PostDisplayType] = [.mediaArrangement, .shortWithImage, .videoClip]
            return mediaTypes.contains(post.displayType)
        case .links:
            return post.displayType == .linkCard
        case .unpublished:
            return post.publishToWeb == false
        }
    }
}
