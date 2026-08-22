//
//  MediaDrop.swift
//  jez-blog
//
//  Drag and drop, always available. Any view can become a media drop target:
//  the whole pane accepts files, highlights while a drag is overhead, and the
//  router decides where the files belong.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Environment

private struct MediaDropTargetedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while a media drag is hovering the enclosing drop target. Lets
    /// nested placeholders (empty slots, drop zones) light up together.
    var isMediaDropTargeted: Bool {
        get { self[MediaDropTargetedKey.self] }
        set { self[MediaDropTargetedKey.self] = newValue }
    }
}

// MARK: - Modifier

/// Makes a view accept media files dropped anywhere inside it.
struct MediaDropTarget: ViewModifier {
    let kinds: Set<AssetType>
    let hint: String
    let onDrop: ([URL]) -> Void

    @State private var isTargeted = false
    @State private var isProcessing = false

    func body(content: Content) -> some View {
        content
            .environment(\.isMediaDropTargeted, isTargeted)
            .overlay {
                if isTargeted { ring.transition(.opacity) }
            }
            .overlay(alignment: .top) {
                if isTargeted { banner.transition(.move(edge: .top).combined(with: .opacity)) }
            }
            .animation(Theme.hover, value: isTargeted)
            .onDrop(of: supportedTypes, isTargeted: $isTargeted) { providers in
                return handleDrop(providers: providers)
            }
    }
    
    private var supportedTypes: [UTType] {
        var types: [UTType] = [.fileURL]
        if kinds.contains(.image) {
            types.append(contentsOf: [.image, .jpeg, .png, .heic, .tiff])
        }
        if kinds.contains(.video) {
            types.append(contentsOf: [.movie, .video, .mpeg4Movie, .quickTimeMovie])
        }
        return types
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !kinds.isEmpty, !isProcessing else { return false }
        
        isProcessing = true
        
        Task {
            let urls = await loadURLs(from: providers)
            
            await MainActor.run {
                isProcessing = false
                
                let accepted = urls.filter { url in
                    guard let kind = MediaStore.assetType(for: url) else { return false }
                    return kinds.contains(kind)
                }
                
                guard !accepted.isEmpty else { return }
                onDrop(accepted)
            }
        }
        
        return true
    }
    
    private func loadURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        
        for provider in providers {
            // Try file URL first (Finder drops)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                if let url = await loadFileURL(from: provider) {
                    urls.append(url)
                    continue
                }
            }
            
            // Try Photos app items (images and videos)
            if let url = await loadPhotosItem(from: provider) {
                urls.append(url)
            }
        }
        
        return urls
    }
    
    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
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
    
    private func loadPhotosItem(from provider: NSItemProvider) async -> URL? {
        // Check for videos FIRST since video providers may also have image
        // representations (thumbnails/poster frames) that we'd incorrectly match
        // Always check for videos first (regardless of kinds) since video 
        // providers may also have image representations we'd incorrectly match
        for videoType in [UTType.movie, .video, .mpeg4Movie, .quickTimeMovie] {
            if provider.hasItemConformingToTypeIdentifier(videoType.identifier) {
                if let url = await loadPhotosVideo(from: provider, type: videoType) {
                    return url
                }
            }
        }
        
        // Then try to load as image
        if kinds.contains(.image) {
            for imageType in [UTType.image, .jpeg, .png, .heic, .tiff] {
                if provider.hasItemConformingToTypeIdentifier(imageType.identifier) {
                    if let url = await loadPhotosImage(from: provider, type: imageType) {
                        return url
                    }
                }
            }
        }
        
        return nil
    }
    
    private func loadPhotosImage(from provider: NSItemProvider, type: UTType) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                guard let data = data, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Create a temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let ext = type.preferredFilenameExtension ?? "jpg"
                let filename = "photos-import-\(UUID().uuidString).\(ext)"
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
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                guard let sourceURL = url, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Copy to a permanent temporary location since the provided URL is temporary
                let tempDir = FileManager.default.temporaryDirectory
                let ext = type.preferredFilenameExtension ?? "mov"
                let filename = "photos-import-\(UUID().uuidString).\(ext)"
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

    private var ring: some View {
        RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
            .strokeBorder(
                Theme.accent.opacity(0.8),
                style: StrokeStyle(lineWidth: 2, dash: [7, 5])
            )
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(Theme.accent.opacity(0.06))
            )
            .allowsHitTesting(false)
    }

    private var banner: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle.fill")
            Text(hint)
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .padding(.top, 14)
        .allowsHitTesting(false)
    }
}

extension View {
    /// Accepts media files dropped anywhere inside this view.
    func mediaDrop(
        kinds: Set<AssetType>,
        hint: String = "Drop to add",
        onDrop: @escaping ([URL]) -> Void
    ) -> some View {
        modifier(MediaDropTarget(kinds: kinds, hint: hint, onDrop: onDrop))
    }
}

// MARK: - Routing

/// Decides what a post can accept and files dropped media into the right place,
/// so every drop target behaves the same way.
@MainActor
enum MediaDropRouter {

    /// The most images a single post holds.
    static let imageLimit = 25

    /// Everything a brand new post could be made from.
    static let creationKinds: Set<AssetType> = [.image, .video]

    /// What the open post is willing to take.
    static func acceptedKinds(for post: Post?) -> Set<AssetType> {
        guard let post else { return creationKinds }

        switch post.displayType {
        case .mediaArrangement, .shortWithImage:
            return [.image]
        case .videoClip:
            return [.video]
        case .thread:
            return creationKinds
        case .linkCard, .singlePost:
            return []
        }
    }

    /// The wording shown while a drag hovers.
    static func hint(for post: Post?) -> String {
        let kinds = acceptedKinds(for: post)

        if kinds == [.image] { return "Drop images here" }
        if kinds == [.video] { return "Drop a video here" }
        if kinds.isEmpty { return "This post cannot take media" }
        return post == nil ? "Drop files to start a post" : "Drop images or a video here"
    }

    /// Files the dropped URLs into `post`. Returns a message when something
    /// could not be imported.
    @discardableResult
    static func handle(_ urls: [URL], post: Post, context: ModelContext) -> String? {
        let accepted = acceptedKinds(for: post)
        let editor = MediaEditor(post: post, context: context)

        let images = urls.filter { MediaStore.assetType(for: $0) == .image }
        let videos = urls.filter { MediaStore.assetType(for: $0) == .video }

        if accepted.contains(.image), !images.isEmpty {
            let room = imageLimit - editor.count(of: .image)
            guard room > 0 else { return "This post already holds \(imageLimit) images." }

            // A single image landing in an empty single-image post replaces it.
            if post.displayType == .shortWithImage, editor.count(of: .image) == 1, images.count == 1 {
                return editor.replaceSingle(kind: .image, with: images)
            }
            return editor.importFiles(images, kind: .image, limit: room)
        }

        if accepted.contains(.video), !videos.isEmpty {
            return editor.replaceSingle(kind: .video, with: videos)
        }

        if accepted.isEmpty { return "A link card holds a link, not a file." }
        return "Nothing here fits this post."
    }

    /// The post type that best suits a set of dropped files.
    static func suggestedType(for urls: [URL]) -> PostDisplayType? {
        let images = urls.filter { MediaStore.assetType(for: $0) == .image }
        let videos = urls.filter { MediaStore.assetType(for: $0) == .video }

        if !images.isEmpty { return images.count == 1 ? .shortWithImage : .mediaArrangement }
        if !videos.isEmpty { return .videoClip }
        return nil
    }
}
