//
//  Folder.swift
//  jez-blog
//
//  User-created folders for organizing posts.
//

import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = "New Folder"
    var createdAt: Date = Date()
    var orderIndex: Int = 0
    
    // Note: We don't define the inverse relationship here to avoid circular reference
    // Posts in this folder are found via query in FolderSectionView
    
    init(
        id: UUID = UUID(),
        name: String = "New Folder",
        createdAt: Date = Date(),
        orderIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.orderIndex = orderIndex
    }
    
}
