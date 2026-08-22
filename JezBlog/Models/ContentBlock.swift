//
//  ContentBlock.swift
//  jez-blog
//

import Foundation
import SwiftData

@Model
final class ContentBlock {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var content: String = ""
    var blockTypeRaw: String = BlockType.text.rawValue
    var characterLimit: Int? = 280

    @Relationship(inverse: \Post.blocks) var post: Post?

    init(
        id: UUID = UUID(),
        orderIndex: Int = 0,
        content: String = "",
        blockType: BlockType = .text,
        characterLimit: Int? = 280
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.content = content
        self.blockTypeRaw = blockType.rawValue
        self.characterLimit = characterLimit
    }

    /// Strongly typed accessor for the persisted raw value.
    var blockType: BlockType {
        get { BlockType(rawValue: blockTypeRaw) ?? .text }
        set { blockTypeRaw = newValue.rawValue }
    }

    var characterCount: Int { content.count }

    var isOverLimit: Bool {
        guard let limit = characterLimit else { return false }
        return characterCount > limit
    }

    var remainingCharacters: Int? {
        guard let limit = characterLimit else { return nil }
        return limit - characterCount
    }
}
