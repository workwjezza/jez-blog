//
//  FolderSectionView.swift
//  jez-blog
//
//  Folder management with drag-and-drop support for posts and files.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FolderSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.orderIndex) var folders: [Folder]
    @Query(sort: \Post.createdAt, order: .reverse) var allPosts: [Post]
    
    @Binding var selectedFolder: Folder?
    var selectedCollection: PostCollection
    var selectedTag: String?
    
    @State private var isExpanded = true
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @State private var editingFolder: Folder?
    @State private var editingName = ""
    @State private var dropTargetFolder: Folder?
    
    /// Returns the count of posts in a given folder
    private func postCount(for folder: Folder) -> Int {
        allPosts.filter { $0.folder?.id == folder.id }.count
    }
    
    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(folders) { folder in
                    folderRow(folder)
                }
                .onMove(perform: moveFolders)
                .onDelete(perform: deleteFolders)
                
                if isCreatingFolder {
                    newFolderInput
                }
            } label: {
                HStack {
                    Label("Folders", systemImage: "folder")
                        .font(.callout)
                    Spacer()
                    Button {
                        withAnimation(Theme.spring) {
                            isCreatingFolder = true
                            newFolderName = "New Folder"
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Create new folder")
                }
            }
        }
    }
    
    // MARK: - Folder Row
    
    private func folderRow(_ folder: Folder) -> some View {
        let isSelected = selectedFolder?.id == folder.id
        let isDropTarget = dropTargetFolder?.id == folder.id
        
        return Group {
            if editingFolder?.id == folder.id {
                folderEditField
            } else {
                folderButton(folder, isSelected: isSelected, isDropTarget: isDropTarget)
            }
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor(for: isSelected, isDropTarget: isDropTarget))
        )
    }
    
    private func folderButton(_ folder: Folder, isSelected: Bool, isDropTarget: Bool) -> some View {
        Button {
            withAnimation(Theme.spring) {
                selectedFolder = isSelected ? nil : folder
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "folder.fill" : "folder")
                    .foregroundStyle(isSelected ? Theme.accent : .secondary)
                
                Text(folder.name)
                    .font(.callout)
                
                Spacer()
                
                let count = postCount(for: folder)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Theme.accent : .primary)
        .onDrop(of: [.plainText, .url, .fileURL], isTargeted: .init(
            get: { dropTargetFolder?.id == folder.id },
            set: { isTargeted in
                withAnimation(Theme.hover) {
                    dropTargetFolder = isTargeted ? folder : nil
                }
            }
        )) { providers in
            handleDrop(providers: providers, into: folder)
        }
        .contextMenu {
            Button {
                editingFolder = folder
                editingName = folder.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                deleteFolder(folder)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Edit Field
    
    private var folderEditField: some View {
        HStack {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            
            TextField("Folder name", text: $editingName)
                .font(.callout)
                .textFieldStyle(.plain)
                .onSubmit {
                    saveFolderRename()
                }
        }
        .padding(.vertical, 4)
        .onAppear {
            // Auto-focus would go here if available
        }
        .onExitCommand {
            editingFolder = nil
        }
    }
    
    // MARK: - New Folder Input
    
    private var newFolderInput: some View {
        HStack {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            
            TextField("Folder name", text: $newFolderName)
                .font(.callout)
                .textFieldStyle(.plain)
                .onSubmit {
                    createFolder()
                }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Views
    
    private func backgroundColor(for isSelected: Bool, isDropTarget: Bool) -> Color {
        if isDropTarget {
            return Theme.accent.opacity(0.25)
        }
        if isSelected {
            return Theme.accent.opacity(0.18)
        }
        return .clear
    }
    
    // MARK: - Actions
    
    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            isCreatingFolder = false
            return
        }
        
        let folder = Folder(
            name: name,
            orderIndex: folders.count
        )
        modelContext.insert(folder)
        
        withAnimation(Theme.spring) {
            isCreatingFolder = false
            newFolderName = ""
        }
    }
    
    private func saveFolderRename() {
        guard let folder = editingFolder else { return }
        let name = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !name.isEmpty {
            folder.name = name
        }
        
        withAnimation(Theme.spring) {
            editingFolder = nil
        }
    }
    
    private func deleteFolder(_ folder: Folder) {
        // Remove posts from folder (but keep the posts)
        let postsInFolder = allPosts.filter { $0.folder?.id == folder.id }
        for post in postsInFolder {
            post.folder = nil
        }
        
        if selectedFolder?.id == folder.id {
            selectedFolder = nil
        }
        
        modelContext.delete(folder)
        
        // Reindex remaining folders
        reindexFolders()
    }
    
    private func deleteFolders(at offsets: IndexSet) {
        for index in offsets {
            let folder = folders[index]
            deleteFolder(folder)
        }
    }
    
    private func moveFolders(from source: IndexSet, to destination: Int) {
        var reordered = folders
        reordered.move(fromOffsets: source, toOffset: destination)
        
        for (index, folder) in reordered.enumerated() {
            folder.orderIndex = index
        }
    }
    
    private func reindexFolders() {
        for (index, folder) in folders.enumerated() {
            folder.orderIndex = index
        }
    }
    
    // MARK: - Drop Handling
    
    private func handleDrop(providers: [NSItemProvider], into folder: Folder) -> Bool {
        Task {
            await MainActor.run {
                dropTargetFolder = nil
            }
            
            // Try to get post IDs (for dragging from timeline)
            for provider in providers {
                if let postID = await loadPostID(from: provider) {
                    await MainActor.run {
                        if let post = findPost(by: postID) {
                            // Remove from previous folder if any
                            post.folder = folder
                        }
                    }
                } else if let urls = await loadFileURLs(from: provider) {
                    // Handle file drop - create posts and add to folder
                    await MainActor.run {
                        createPostsFromFiles(urls, in: folder)
                    }
                }
            }
        }
        
        return true
    }
    
    private func loadPostID(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let string = String(data: data, encoding: .utf8),
                   string.hasPrefix("post:") {
                    let id = String(string.dropFirst(5))
                    continuation.resume(returning: id)
                } else if let string = item as? String, string.hasPrefix("post:") {
                    let id = String(string.dropFirst(5))
                    continuation.resume(returning: id)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func loadFileURLs(from provider: NSItemProvider) async -> [URL]? {
        var urls: [URL] = []
        
        // Try file URL (Finder drops)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
                return urls
            }
        }
        
        // Check for videos FIRST (before images) since video providers may also
        // have image representations (thumbnails) that we'd incorrectly match
        for videoType in [UTType.movie, .video, .mpeg4Movie, .quickTimeMovie] {
            if provider.hasItemConformingToTypeIdentifier(videoType.identifier) {
                if let url = await loadPhotosVideo(from: provider, type: videoType) {
                    urls.append(url)
                    return urls
                }
            }
        }
        
        // Then check for images
        for imageType in [UTType.image, .jpeg, .png, .heic, .tiff] {
            if provider.hasItemConformingToTypeIdentifier(imageType.identifier) {
                if let url = await loadPhotosItem(from: provider, type: imageType) {
                    urls.append(url)
                    return urls
                }
            }
        }
        
        return urls.isEmpty ? nil : urls
    }
    
    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func loadPhotosItem(from provider: NSItemProvider, type: UTType) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                guard let data = data else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let tempDir = FileManager.default.temporaryDirectory
                let ext = type.preferredFilenameExtension ?? "jpg"
                let filename = "folder-import-\(UUID().uuidString).\(ext)"
                let tempURL = tempDir.appendingPathComponent(filename)
                
                do {
                    try data.write(to: tempURL)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func loadPhotosVideo(from provider: NSItemProvider, type: UTType) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                guard let sourceURL = url else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let tempDir = FileManager.default.temporaryDirectory
                let ext = type.preferredFilenameExtension ?? "mov"
                let filename = "folder-import-\(UUID().uuidString).\(ext)"
                let tempURL = tempDir.appendingPathComponent(filename)
                
                do {
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: tempURL)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func findPost(by id: String) -> Post? {
        // Filter from already-fetched posts instead of using a predicate
        // (SwiftData predicates can't traverse into UUID value types)
        return allPosts.first { $0.id.uuidString == id }
    }
    
    private func createPostsFromFiles(_ urls: [URL], in folder: Folder) {
        guard let type = MediaDropRouter.suggestedType(for: urls) else { return }
        
        for url in urls {
            let post = Post(intendedType: type)
            modelContext.insert(post)
            
            // Set folder
            post.folder = folder
            
            // Add media
            MediaDropRouter.handle([url], post: post, context: modelContext)
            
            // For threads, add an initial block
            if type == .thread {
                let block = ContentBlock(orderIndex: 0)
                modelContext.insert(block)
                post.blocks = [block]
            } else if type == .singlePost {
                let block = ContentBlock(orderIndex: 0, characterLimit: PostDisplayType.singlePostCharacterLimit)
                modelContext.insert(block)
                post.blocks = [block]
            }
        }
    }
}

// MARK: - Post ID Transfer

extension UTType {
    static var postID: UTType {
        UTType(exportedAs: "com.jezblog.post-id")
    }
}
