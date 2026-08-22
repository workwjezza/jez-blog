//
//  ThreePaneView.swift
//  jez-blog
//
//  Sidebar · Timeline · Editor
//

import AppKit
import Combine
import SwiftData
import SwiftUI

struct ThreePaneView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Post.createdAt, order: .reverse) private var posts: [Post]

    @State private var selectedCollection: PostCollection = .all
    @State private var selectedTag: String?
    @State private var selectedFolder: Folder?
    @State private var selectedPost: Post?
    @State private var searchText: String = ""
    @State private var prefersGallery: Bool = true
    @State private var exportSummary: ExportSummary?
    @State private var exportError: String?


    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedCollection: $selectedCollection,
                selectedTag: $selectedTag,
                selectedFolder: $selectedFolder,
                searchText: $searchText,
                tags: allTags,
                onNewPost: createPost
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 320)
        } content: {
            TimelineView(
                posts: filteredPosts,
                selectedPost: $selectedPost,
                collectionTitle: timelineTitle,
                postCount: filteredPosts.count,
                allowsGallery: allowsGallery,
                prefersGallery: $prefersGallery,
                onNewPost: createPost,
                onImportFiles: createPost(with:)
            )
            .navigationSplitViewColumnWidth(min: 320, ideal: 400, max: 560)
        } detail: {
            DetailContainerView(
                post: selectedPost,
                onDelete: delete,
                onNewPost: createPost,
                onImportFiles: createPost(with:)
            )

            .navigationSplitViewColumnWidth(min: 480, ideal: 800, max: .infinity)
        }
        .navigationTitle("jez-blog")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: exportSite) {
                    Label("Export Site", systemImage: "square.and.arrow.up")
                }
                .help("Write the published posts out as a static site (⇧⌘E)")
                .disabled(publishedCount == 0)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newPostRequested)) { notification in
            createPost(NewPostRequest.type(from: notification))
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportSiteRequested)) { _ in
            exportSite()
        }
        .alert("Site exported", isPresented: .constant(exportSummary != nil)) {
            Button("Show in Finder") {
                if let destination = exportSummary?.destination {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [destination.appendingPathComponent("index.html")]
                    )
                }
                exportSummary = nil
            }
            Button("Done", role: .cancel) { exportSummary = nil }
        } message: {
            Text(exportSummary.map(summaryMessage) ?? "")
        }
        .alert("Export failed", isPresented: .constant(exportError != nil)) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .onChange(of: selectedCollection) { _, _ in
            // Keep the selection valid when the collection changes.
            if let selectedPost, !filteredPosts.contains(where: { $0.id == selectedPost.id }) {
                withAnimation(Theme.spring) { self.selectedPost = nil }
            }
        }
        .onChange(of: selectedFolder) { _, _ in
            // Keep the selection valid when the folder changes.
            if let selectedPost, !filteredPosts.contains(where: { $0.id == selectedPost.id }) {
                withAnimation(Theme.spring) { self.selectedPost = nil }
            }
        }
        .onChange(of: searchText) { _, _ in
            // Keep the selection valid when the search changes.
            if let selectedPost, !filteredPosts.contains(where: { $0.id == selectedPost.id }) {
                withAnimation(Theme.spring) { self.selectedPost = nil }
            }
        }
    }

    // MARK: - Derived data

    private var allTags: [String] {
        Array(Set(posts.flatMap(\.tags))).sorted()
    }

    private var filteredPosts: [Post] {
        posts.filter { post in
            // If a folder is selected, only show posts in that folder
            if let selectedFolder {
                return post.folder?.id == selectedFolder.id && post.matches(searchText: searchText)
            }
            
            // Otherwise use collection + tag filtering
            guard selectedCollection.contains(post) else { return false }
            if let selectedTag, !post.tags.contains(selectedTag) { return false }
            return post.matches(searchText: searchText)
        }
    }

    private var timelineTitle: String {
        if let selectedFolder {
            return selectedFolder.name
        }
        if let selectedTag { return "#\(selectedTag)" }
        return selectedCollection.label
    }

    /// The Media collection reads better as a gallery than as a feed.
    private var allowsGallery: Bool {
        selectedCollection == .media && selectedTag == nil && selectedFolder == nil
    }


    private var publishedCount: Int {
        posts.filter(\.publishToWeb).count
    }

    // MARK: - Actions

    private func createPost(_ type: PostDisplayType) {
        makePost(type)
    }

    /// Inserts a post of `type`, selects it and hands it back.
    @discardableResult
    private func makePost(_ type: PostDisplayType) -> Post {
        let post = Post(intendedType: type)

        modelContext.insert(post)

        // Text-first posts open with one block ready for typing; media posts
        // start with the picture only — a caption is added if it is wanted.
        if type == .thread {

            let block = ContentBlock(orderIndex: 0)
            modelContext.insert(block)
            post.blocks = [block]
        } else if type == .singlePost {
            // Single posts also need their one block ready
            let block = ContentBlock(orderIndex: 0, characterLimit: PostDisplayType.singlePostCharacterLimit)
            modelContext.insert(block)
            post.blocks = [block]
        }

        reveal(post)
        return post
    }

    /// Files dropped on the timeline or the empty editor become a new post of
    /// the kind that suits them.
    private func createPost(with urls: [URL]) {
        guard let type = MediaDropRouter.suggestedType(for: urls) else { return }

        let post = makePost(type)
        MediaDropRouter.handle(urls, post: post, context: modelContext)
        reveal(post)
    }


    /// Clears any filter that would hide the post, then selects it.
    private func reveal(_ post: Post) {
        withAnimation(Theme.spring) {
            selectedTag = nil
            
            // If post is in a folder, switch to that folder
            if let folder = post.folder {
                selectedFolder = folder
            } else if !selectedCollection.contains(post) {
                selectedCollection = .all
                selectedFolder = nil
            }
            
            searchText = ""
            selectedPost = post
        }
    }


    /// Asks for a folder, then writes index.html, the post pages and the media.
    private func exportSite() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"
        panel.message = "Choose a folder for the exported site."

        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            exportSummary = try SiteExporter.export(posts: posts, to: destination)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func summaryMessage(for summary: ExportSummary) -> String {
        var lines = [
            "\(summary.postCount) post\(summary.postCount == 1 ? "" : "s") and \(summary.mediaCount) file\(summary.mediaCount == 1 ? "" : "s") written to \"\(summary.destination.lastPathComponent)\"."
        ]
        if summary.skippedMediaCount > 0 {
            lines.append("\(summary.skippedMediaCount) missing file\(summary.skippedMediaCount == 1 ? " was" : "s were") skipped.")
        }
        return lines.joined(separator: "\n")
    }

    private func delete(_ post: Post) {
        withAnimation(Theme.spring) {
            if selectedPost?.id == post.id { selectedPost = nil }
            modelContext.delete(post)
        }
    }
}

#Preview {
    ThreePaneView()
        .frame(width: 1400, height: 900)
        .modelContainer(for: [Post.self, ContentBlock.self, MediaAsset.self, Folder.self], inMemory: true)
}
