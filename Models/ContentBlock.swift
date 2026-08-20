//
//  ContentBlock.swift
//  jez-blog
//
//  Content block model for text and embeds
//

import Foundation
import SwiftData

@Model
class ContentBlock {
    var id: UUID
    var orderIndex: Int
    var content: String
    var blockType: BlockType
    var characterLimit: Int? // 280 for tweet-length
    
    @Relationship(inverse: \Post.blocks) var post: Post?
    
    init(id: UUID = UUID(), orderIndex: Int = 0, content: String = "", blockType: BlockType = .text, characterLimit: Int? = 280) {
        self.id = id
        self.orderIndex = orderIndex
        self.content = content
        self.blockType = blockType
        self.characterLimit = characterLimit
    }
}
