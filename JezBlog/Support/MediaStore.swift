//
//  MediaStore.swift
//  jez-blog
//
//  Owns the on-disk media library. Imported files are *copied* into the app's
//  container so a post keeps working after the original is moved or renamed.
//

import AVFoundation
import AppKit
import Foundation
import ImageIO
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum MediaStoreError: LocalizedError {
    case unreadable(URL)
    case unsupported(URL)
    case copyFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .unreadable(let url):
            return "“\(url.lastPathComponent)” could not be read."
        case .unsupported(let url):
            return "“\(url.lastPathComponent)” is not a supported media file."
        case .copyFailed(let url, let error):
            return "“\(url.lastPathComponent)” could not be imported — \(error.localizedDescription)"
        }
    }
}

enum MediaStore {

    // MARK: - Accepted types

    static let imageContentTypes: [UTType] = [.image]
    static let videoContentTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]

    /// Classifies a file on disk so the right asset type is stored.
    static func assetType(for url: URL) -> AssetType? {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return nil }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        return nil
    }

    // MARK: - Location

    /// `…/Application Support/JezBlog/Media`
    static var mediaDirectory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("JezBlog", isDirectory: true)
            .appendingPathComponent("Media", isDirectory: true)
    }

    // MARK: - Importing

    /// Copies `source` into the media folder and returns the stored absolute path.
    static func importFile(at source: URL, expecting kind: AssetType? = nil) throws -> String {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        guard let detected = assetType(for: source) else { throw MediaStoreError.unsupported(source) }
        if let kind, kind != detected { throw MediaStoreError.unsupported(source) }
        guard FileManager.default.isReadableFile(atPath: source.path) else {
            throw MediaStoreError.unreadable(source)
        }

        let directory = mediaDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let name = source.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let stem = name.isEmpty ? "media" : String(name.prefix(48))
        let extension_ = source.pathExtension.isEmpty ? "dat" : source.pathExtension.lowercased()
        let unique = String(UUID().uuidString.prefix(8)).lowercased()
        let destination = directory.appendingPathComponent("\(stem)-\(unique).\(extension_)")

        do {
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            throw MediaStoreError.copyFailed(source, error)
        }

        return destination.path
    }

    /// Removes a stored file. Missing files are ignored.
    static func removeFile(atPath path: String?) {
        guard let path, path.hasPrefix(mediaDirectory.path) else { return }
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
    }

    /// Renames a stored file. Returns the new path on success, nil on failure.
    static func renameFile(atPath path: String, to newName: String) -> String? {
        guard path.hasPrefix(mediaDirectory.path) else { return nil }
        
        let oldURL = URL(fileURLWithPath: path)
        let directory = oldURL.deletingLastPathComponent()
        let ext = oldURL.pathExtension
        
        // Sanitize the new name
        let sanitized = newName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let stem = sanitized.isEmpty ? "media" : String(sanitized.prefix(48))
        
        // Keep the extension
        let finalName = ext.isEmpty ? stem : "\(stem).\(ext)"
        let newURL = directory.appendingPathComponent(finalName)
        
        // Don't overwrite existing files
        guard !FileManager.default.fileExists(atPath: newURL.path) else { return nil }
        
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            return newURL.path
        } catch {
            return nil
        }
    }

    // MARK: - Inspection

    /// A human readable file size, e.g. "2.4 MB".
    static func fileSizeDescription(atPath path: String?) -> String? {
        guard
            let path,
            let attributes = try? FileManager.default.attributesOfItem(atPath: path),
            let bytes = attributes[.size] as? Int64
        else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Duration of a video or audio file in seconds.
    static func duration(atPath path: String) async -> Double? {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        do {
            let duration = try await asset.load(.duration).seconds
            return duration.isFinite && duration > 0 ? duration : nil
        } catch {
            return nil
        }
    }

    /// Pixel dimensions of an image, used for the exported markup.
    static func pixelSize(atPath path: String) -> CGSize? {
        guard
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Double,
            let height = properties[kCGImagePropertyPixelHeight] as? Double
        else { return nil }
        return CGSize(width: width, height: height)
    }

    // MARK: - Thumbnails

    /// Renders a thumbnail and returns it as PNG data so it can cross
    /// concurrency domains safely. Views turn it back into an `NSImage`.
    static func thumbnailData(
        atPath path: String,
        kind: AssetType,
        maxPixelSize: CGFloat = 1200
    ) async -> Data? {
        switch kind {
        case .image:
            return await Task.detached(priority: .userInitiated) {
                imageThumbnailData(atPath: path, maxPixelSize: maxPixelSize)
            }.value
        case .video:
            return await videoPosterData(atPath: path, maxPixelSize: maxPixelSize)
        case .audio, .linkPreview:
            return nil
        }
    }

    private static func imageThumbnailData(atPath path: String, maxPixelSize: CGFloat) -> Data? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return pngData(from: image)
    }

    private static func videoPosterData(atPath path: String, maxPixelSize: CGFloat) async -> Data? {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)

        do {
            let time = CMTime(seconds: 0.2, preferredTimescale: 600)
            let frame = try await generator.image(at: time).image
            return pngData(from: frame)
        } catch {
            return nil
        }
    }

    private static func pngData(from image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}

// MARK: - Model editing

/// Attaches, removes and reorders a post's media so every editor mutates the
/// model the same way — and so the on-disk library never leaks orphans.
@MainActor
struct MediaEditor {
    let post: Post
    let context: ModelContext

    /// Number of images/videos already attached.
    func count(of kind: AssetType) -> Int {
        post.sortedAssets.filter { $0.assetType == kind }.count
    }

    /// Imports up to `limit` files at the end. Returns a message when something went wrong.
    @discardableResult
    func importFiles(_ urls: [URL], kind: AssetType, limit: Int = .max) -> String? {
        guard limit > 0 else { return "There is no room for another \(kind.rawValue)." }

        var failures: [String] = []
        var imported: [MediaAsset] = []

        for url in urls.prefix(limit) {
            do {
                let path = try MediaStore.importFile(at: url, expecting: kind)
                let asset = MediaAsset(
                    orderIndex: (post.mediaAssets?.count ?? 0) + imported.count,
                    assetType: kind,
                    localPath: path
                )
                context.insert(asset)
                imported.append(asset)
            } catch {
                failures.append(error.localizedDescription)
            }
        }

        if !imported.isEmpty {
            withAnimation(Theme.spring) {
                var updated = post.mediaAssets ?? []
                updated.append(contentsOf: imported)
                post.mediaAssets = updated
                reindex()
                post.touch()
            }

            if kind == .video || kind == .audio {
                let assets = imported
                Task { for asset in assets { await loadDuration(for: asset) } }
            }
        }

        if let failure = failures.first { return failure }
        if urls.count > limit { return "Only \(limit) more file\(limit == 1 ? "" : "s") fit here." }
        return nil
    }
    
    /// Imports files at the beginning (reverse chronological order).
    /// Shifts existing items to make room for new items at the top.
    @discardableResult
    func importFilesAtBeginning(_ urls: [URL], kind: AssetType, limit: Int = .max) -> String? {
        guard limit > 0 else { return "There is no room for another \(kind.rawValue)." }
        
        var failures: [String] = []
        var imported: [MediaAsset] = []
        let itemsToImport = Array(urls.prefix(limit))
        
        // Shift existing assets to make room at the beginning
        let existingAssets = post.sortedAssets
        for asset in existingAssets {
            asset.orderIndex += itemsToImport.count
        }
        
        // Import new files at the beginning
        for (index, url) in itemsToImport.enumerated() {
            do {
                let path = try MediaStore.importFile(at: url, expecting: kind)
                let asset = MediaAsset(
                    orderIndex: index,  // Position at the beginning
                    assetType: kind,
                    localPath: path
                )
                context.insert(asset)
                imported.append(asset)
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        
        if !imported.isEmpty {
            withAnimation(Theme.spring) {
                var updated = post.mediaAssets ?? []
                updated.append(contentsOf: imported)
                post.mediaAssets = updated
                post.touch()
            }
            
            if kind == .video || kind == .audio {
                let assets = imported
                Task { for asset in assets { await loadDuration(for: asset) } }
            }
        }
        
        if let failure = failures.first { return failure }
        if urls.count > limit { return "Only \(limit) more file\(limit == 1 ? "" : "s") fit here." }
        return nil
    }

    /// Swaps in a single asset, used by Short + Image and Video Clip.
    @discardableResult
    func replaceSingle(kind: AssetType, with urls: [URL]) -> String? {
        guard let first = urls.first else { return nil }
        for existing in post.sortedAssets where existing.assetType == kind {
            remove(existing)
        }
        return importFiles([first], kind: kind, limit: 1)
    }

    /// Deletes the asset and its file.
    func remove(_ asset: MediaAsset) {
        MediaStore.removeFile(atPath: asset.localPath)

        withAnimation(Theme.spring) {
            post.mediaAssets?.removeAll { $0.id == asset.id }
            context.delete(asset)
            reindex()
            post.touch()
        }
    }

    /// Swaps an asset with its neighbour (-1 earlier, +1 later).
    func move(_ asset: MediaAsset, by offset: Int) {
        let ordered = post.sortedAssets
        guard
            let index = ordered.firstIndex(where: { $0.id == asset.id }),
            ordered.indices.contains(index + offset)
        else { return }

        let neighbour = ordered[index + offset]

        withAnimation(Theme.spring) {
            let temporary = asset.orderIndex
            asset.orderIndex = neighbour.orderIndex
            neighbour.orderIndex = temporary
            post.touch()
        }
    }

    /// Normalises order indices to 0..<n.
    func reindex() {
        for (index, asset) in post.sortedAssets.enumerated() {
            asset.orderIndex = index
        }
    }

    /// Caches a clip's duration for the editor and the exported page.
    func loadDuration(for asset: MediaAsset) async {
        guard let path = asset.localPath, asset.durationSeconds == nil else { return }
        if let duration = await MediaStore.duration(atPath: path) {
            asset.durationSeconds = duration
        }
    }
}
