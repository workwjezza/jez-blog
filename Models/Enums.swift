//
//  Enums.swift
//  jez-blog
//
//  Data model enumerations and supporting structures
//

import Foundation

enum PostDisplayType: String, Codable {
    case thread           // 2-4 text blocks
    case mediaArrangement // 1-4 images in grid
    case shortWithImage   // 1 text block + 1 image
    case videoClip        // single video
    case linkCard         // URL with preview
}

enum BlockType: String, Codable {
    case text
    case embed
    case spacer
}

enum AssetType: String, Codable {
    case image
    case video
    case audio
    case linkPreview
}

struct MediaArrangement: Codable, Equatable {
    var x: Int      // 0-1 grid position
    var y: Int      // 0-1 grid position
    var width: Int  // 1-2 spans
    var height: Int // 1-2 spans
}
