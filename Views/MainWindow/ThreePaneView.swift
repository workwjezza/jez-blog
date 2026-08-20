//
//  ThreePaneView.swift
//  jez-blog
//
//  Main three-pane layout using NavigationSplitView
//

import SwiftUI
import SwiftData

enum CollectionType: String, CaseIterable {
    case all = "All Posts"
    case threads = "Threads"
    case media = "Media"
    case links = "Links"
    case unpublished = "Unpublished"
}

struct ThreePaneView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.modifiedAt, order: .reverse) private var allPosts: [Post]
    
    @State private var selectedCollection: CollectionType = .all
    @State private var selectedTag: String?
    @State private var selectedPost: Post?
    @State private var searchText: String = ""
    
    var filteredPosts: [Post] {
        var posts = allPosts
        
        // Filter by collection
        switch selectedCollection {
        case .all:
            break
        case .threads:
            posts = posts.filter { $0.displayType == .thread }
        case .media:
            posts = posts.filter { $0.displayType == .mediaArrangement }
        case .links:
            posts = posts.filter { $0.displayType == .linkCard }
        case .unpublished:
            posts = posts.filter { !$0.publishToWeb }
        }
        
        // Filter by tag
        if let tag = selectedTag {
            posts = posts.filter { $0.tags.contains(tag) }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            posts = posts.filter { post in
                // Search in blocks content
                if let blocks = post.blocks {
                    for block in blocks {
                        if block.content.localizedCaseInsensitiveContains(searchText) {
                            return true
                        }
                    }
                }
                // Search in tags
                return post.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return posts
    }
    
    var allTags: [String] {
        let tagSet = Set(allPosts.flatMap { $0.tags })
        return Array(tagSet).sorted()
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedCollection: $selectedCollection,
                selectedTag: $selectedTag,
                allTags: allTags,
                onCreatePost: createNewPost
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } content: {
            TimelineView(
                posts: filteredPosts,
                searchText: $searchText,
                selectedPost: $selectedPost
            )
            .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
        } detail: {
            DetailContainerView(post: selectedPost)
                .navigationSplitViewColumnWidth(min: 600, ideal: 800, max: 1200)
        }
    }
    
    private func createNewPost(type: PostDisplayType) {
        let newPost = Post()
        modelContext.insert(newPost)
        
        // Initialize with appropriate content based on type
        switch type {
        case .thread:
            let block = ContentBlock(orderIndex: 0, content: "", blockType: .text, characterLimit: 280)
            block.post = newPost
            modelContext.insert(block)
            newPost.blocks = [block]
        case .mediaArrangement:
            // Create placeholder media assets
            for i in 0..<4 {
                let asset = MediaAsset(orderIndex: i, assetType: .image)
                asset.post = newPost
                modelContext.insert(asset)
            }
            newPost.mediaAssets = modelContext.model(for: newPost.id)?.mediaAssets ?? []
        case .shortWithImage:
            let block = ContentBlock(orderIndex: 0, content: "", blockType: .text, characterLimit: nil)
            block.post = newPost
            modelContext.insert(block)
            
            let asset = MediaAsset(orderIndex: 0, assetType: .image)
            asset.post = newPost
            modelContext.insert(asset)
        case .videoClip:
            let asset = MediaAsset(orderIndex: 0, assetType: .video)
            asset.post = newPost
            modelContext.insert(asset)
        case .linkCard:
            let asset = MediaAsset(orderIndex: 0, assetType: .linkPreview)
            asset.post = newPost
            modelContext.insert(asset)
        }
        
        try? modelContext.save()
        selectedPost = newPost
    }
}
