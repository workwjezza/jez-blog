//
//  MediaPreviewWindow.swift
//  jez-blog
//
//  A picture or a clip, popped out into its own window so it can be seen whole,
//  zoomed into, or handed off to Preview / Finder.
//

#if canImport(AppKit)

import AVKit
import AppKit
import SwiftUI

// MARK: - Item

/// A snapshot of the asset being shown, so the window never touches the model.
struct MediaPreviewItem: Identifiable {
    let id = UUID()
    let path: String
    let kind: AssetType
    let title: String
    let subtitle: String?

    var fileURL: URL { URL(fileURLWithPath: path) }

    init(path: String, kind: AssetType, title: String, subtitle: String? = nil) {
        self.path = path
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
    }

    /// Nil when the asset has no viewable file behind it.
    init?(asset: MediaAsset) {
        guard
            let path = asset.localPath,
            asset.fileExists,
            asset.assetType == .image || asset.assetType == .video
        else { return nil }

        let details = [asset.durationDescription, MediaStore.fileSizeDescription(atPath: path)]
            .compactMap { $0 }
            .joined(separator: " · ")

        self.init(
            path: path,
            kind: asset.assetType,
            title: asset.displayName,
            subtitle: details.isEmpty ? nil : details
        )
    }
}

// MARK: - Window

/// Opens (and keeps alive) the pop-out media windows.
@MainActor
final class MediaPreviewWindowController: NSWindowController, NSWindowDelegate {

    /// Windows currently on screen. Removed again as each one closes.
    private static var live: Set<MediaPreviewWindowController> = []

    /// Pops the asset out into its own resizable window.
    static func show(asset: MediaAsset) {
        guard let item = MediaPreviewItem(asset: asset) else { return }
        show(item)
    }

    static func show(_ item: MediaPreviewItem) {
        let hosting = NSHostingController(rootView: MediaPreviewView(item: item))

        let window = NSWindow(contentViewController: hosting)
        window.title = item.title
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 940, height: 680))
        window.contentMinSize = NSSize(width: 420, height: 320)
        window.isReleasedWhenClosed = false
        window.center()

        let controller = MediaPreviewWindowController(window: window)
        window.delegate = controller
        live.insert(controller)

        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        Self.live.remove(self)
    }
}

// MARK: - View

struct MediaPreviewView: View {
    let item: MediaPreviewItem

    @State private var image: NSImage?
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var zoom: CGFloat = 1

    private let zoomRange: ClosedRange<CGFloat> = 1...6

    var body: some View {
        VStack(spacing: 0) {
            stage
            Divider()
            footer
        }
        .frame(minWidth: 420, minHeight: 320)
        .task(id: item.path) { await load() }
        .onDisappear { player?.pause() }
    }

    // MARK: Stage

    private var stage: some View {
        ZStack {
            Color.black

            switch item.kind {
            case .video:    videoStage
            default:        imageStage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var imageStage: some View {
        if let image {
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: max(proxy.size.width * zoom, 1),
                            height: max(proxy.size.height * zoom, 1)
                        )
                }
                .animation(Theme.hover, value: zoom)
            }
        } else if isLoading {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)
                .fixedSize()
        } else {
            missing
        }
    }

    @ViewBuilder
    private var videoStage: some View {
        if let player {
            StableVideoPlayer(player: player)
        } else if isLoading {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)
                .fixedSize()
        } else {
            missing
        }
    }

    private var missing: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
            Text("The file has moved or been deleted.")
                .font(.caption)
        }
        .foregroundStyle(.white.opacity(0.7))
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if item.kind == .image { zoomControls }

            Button {
                NSWorkspace.shared.open(item.fileURL)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            .help("Open in the system viewer")

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
            } label: {
                Label("Reveal", systemImage: "folder")
            }
            .help("Show in Finder")
        }
        .labelStyle(.iconOnly)
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button { setZoom(zoom - 0.5) } label: { Image(systemName: "minus.magnifyingglass") }
                .disabled(zoom <= zoomRange.lowerBound)
                .help("Zoom out")

            Text("\(Int(zoom * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44)

            Button { setZoom(zoom + 0.5) } label: { Image(systemName: "plus.magnifyingglass") }
                .disabled(zoom >= zoomRange.upperBound)
                .help("Zoom in")

            Button { setZoom(1) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .disabled(zoom == 1)
                .help("Fit to window")
        }
    }

    private func setZoom(_ value: CGFloat) {
        withAnimation(Theme.hover) {
            zoom = min(max(value, zoomRange.lowerBound), zoomRange.upperBound)
        }
    }

    // MARK: Loading

    private func load() async {
        isLoading = true
        image = nil
        player = nil

        guard FileManager.default.fileExists(atPath: item.path) else {
            isLoading = false
            return
        }

        switch item.kind {
        case .video:
            let newPlayer = AVPlayer(url: item.fileURL)
            newPlayer.actionAtItemEnd = .none
            
            // Add observer for looping
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { _ in
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }
            
            player = newPlayer
            newPlayer.play()
        default:
            // Decoded at a generous size: sharp when zoomed, still bounded.
            let data = await MediaStore.thumbnailData(
                atPath: item.path,
                kind: item.kind,
                maxPixelSize: 4096
            )
            guard !Task.isCancelled else { return }
            image = data.flatMap(NSImage.init(data:))
        }

        isLoading = false
    }
}

#else

// MARK: - iOS Stub

import SwiftUI

/// Stub for iOS - media preview windows don't exist on iOS
struct MediaPreviewItem: Identifiable {
    let id = UUID()
    let path: String
    let kind: AssetType
    let title: String
    let subtitle: String?
    
    init(path: String, kind: AssetType, title: String, subtitle: String? = nil) {
        self.path = path
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
    }
    
    init?(asset: MediaAsset) {
        return nil // Not supported on iOS
    }
}

@MainActor
final class MediaPreviewWindowController {
    static func show(asset: MediaAsset) {
        // No-op on iOS
    }
    static func show(_ item: MediaPreviewItem) {
        // No-op on iOS
    }
}

#endif
