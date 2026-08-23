//
//  MediaSlotView.swift
//  jez-blog
//
//  The tile every media editor is built from: empty it invites a drop or a
//  click, filled it shows the real thumbnail with hover controls — and a click
//  pops the picture out into its own window.
//

#if canImport(AppKit)
import AppKit
#endif
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Thumbnail

/// Renders a stored asset's thumbnail, decoded off the main thread.
struct MediaThumbnailView: View {
    let path: String
    let kind: AssetType
    var contentMode: ContentMode = .fill

    /// When true the tile takes the media's own shape, so nothing is cropped.
    var adoptsAspectRatio: Bool = false

    #if canImport(AppKit)
    @State private var image: NSImage?
    #else
    @State private var image: UIImage?
    #endif
    @State private var isLoading = true

    #if canImport(AppKit)
    private var aspectRatio: CGFloat? {
        guard let image, image.size.width > 0, image.size.height > 0 else { return nil }
        return image.size.width / image.size.height
    }
    #else
    private var aspectRatio: CGFloat? {
        guard let image, image.size.width > 0, image.size.height > 0 else { return nil }
        return image.size.width / image.size.height
    }
    #endif

    var body: some View {
        Group {
            if adoptsAspectRatio, let aspectRatio {
                canvas.aspectRatio(aspectRatio, contentMode: .fit)
            } else {
                canvas
            }
        }
        .animation(Theme.spring, value: aspectRatio)
        .task(id: path) {
            isLoading = true
            image = nil

            let data = await MediaStore.thumbnailData(atPath: path, kind: kind)
            guard !Task.isCancelled else { return }

            #if canImport(AppKit)
            image = data.flatMap(NSImage.init(data:))
            #else
            image = data.flatMap(UIImage.init(data:))
            #endif
            isLoading = false
        }
    }

    private var canvas: some View {
        ZStack {
            Theme.cardFill

            if let image {
                #if canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
                #endif
            } else if isLoading {
                // An integral, fixed frame keeps AppKit from logging
                // fractional min/max constraint conflicts for the spinner.
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
                    .fixedSize()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title3)
                    Text("File missing")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .clipped()
        .animation(Theme.hover, value: image == nil)
    }
}

// MARK: - Slot

struct MediaSlotView: View {
    var asset: MediaAsset?
    var kind: AssetType = .image

    var emptySymbol: String = "photo"
    var emptyTitle: String = "Drop an image"
    var emptySubtitle: String? = "or click to choose a file"

    /// In fitted mode this is the tallest the tile may grow; otherwise it is
    /// the exact tile height.
    var height: CGFloat = 170

    var allowsMultiple: Bool = false
    var showsAltText: Bool = false
    var badge: String? = nil

    /// Shows the whole picture — letterboxed to its own shape rather than
    /// cropped to fill the tile.
    var fitsContent: Bool = false

    var canMoveEarlier: Bool = false
    var canMoveLater: Bool = false

    let onImport: ([URL]) -> Void
    var onRemove: (() -> Void)? = nil
    var onMoveEarlier: (() -> Void)? = nil
    var onMoveLater: (() -> Void)? = nil

    /// Dropping is handled by the enclosing pane (see `MediaDropTarget`); the
    /// slot only mirrors the highlight so the placeholder lights up too.
    @Environment(\.isMediaDropTargeted) private var isTargeted

    @State private var isHovering = false
    @State private var isChoosingFile = false


    private var contentTypes: [UTType] {
        switch kind {
        case .video:        return MediaStore.videoContentTypes
        case .audio:        return [.audio]
        case .image:        return MediaStore.imageContentTypes
        case .linkPreview:  return []
        }
    }

    var body: some View {
        Group {
            if let asset, asset.hasContent {
                filled(asset)
            } else {
                empty
            }
        }
        .fileImporter(

            isPresented: $isChoosingFile,
            allowedContentTypes: contentTypes,
            allowsMultipleSelection: allowsMultiple
        ) { result in
            if case .success(let urls) = result { onImport(urls) }
        }
    }

    // MARK: Empty

    private var empty: some View {
        Button {
            isChoosingFile = true
        } label: {
            DropZone(
                symbolName: emptySymbol,
                title: emptyTitle,
                subtitle: emptySubtitle,
                minHeight: height,
                isTargeted: isTargeted
            )
        }
        .buttonStyle(.plain)
        .help("Drop a file anywhere in this editor, or click to browse")
    }


    // MARK: Filled

    private func filled(_ asset: MediaAsset) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            preview(asset)

            if showsAltText {
                TextField("Describe this image…", text: Bindable(asset).altText.orEmpty)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(height: 16)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.cardFill))
                    .help("Alt text, used by the exported page")
            }
        }
    }

    /// The picture itself: whole in fitted mode, cropped to the tile otherwise.
    private func preview(_ asset: MediaAsset) -> some View {
        let thumbnail = MediaThumbnailView(
            path: asset.localPath ?? "",
            kind: kind,
            contentMode: fitsContent ? .fit : .fill,
            adoptsAspectRatio: fitsContent
        )

        return Group {
            if fitsContent {
                // The tile shrinks to the media's own shape, capped at `height`.
                thumbnail.frame(maxHeight: height)
            } else {
                thumbnail
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(isTargeted ? Theme.accent : Theme.hairline, lineWidth: isTargeted ? 2 : 1)
        )
        .overlay(alignment: .topLeading) { badgeView }
        .overlay(alignment: .topTrailing) {
            if isHovering { controls(asset).transition(.opacity) }
        }
        .overlay(alignment: .bottomLeading) {
            if isHovering { caption(asset).transition(.opacity) }
        }
        .shadow(color: .black.opacity(isHovering ? 0.14 : 0.06), radius: isHovering ? 10 : 4, y: isHovering ? 4 : 2)
        .onHover { hovering in
            withAnimation(Theme.hover) { isHovering = hovering }
        }
        .onTapGesture { popOut(asset) }
        .help("Click to open this \(kind == .video ? "clip" : "picture") in its own window")
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var badgeView: some View {
        if let badge {
            Text(badge)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(.ultraThinMaterial))
                .padding(8)
        }
    }

    private func controls(_ asset: MediaAsset) -> some View {
        HStack(spacing: 2) {
            if canMoveEarlier || canMoveLater {
                Button { onMoveEarlier?() } label: { Image(systemName: "arrow.left") }
                    .disabled(!canMoveEarlier)
                    .help("Move earlier")

                Button { onMoveLater?() } label: { Image(systemName: "arrow.right") }
                    .disabled(!canMoveLater)
                    .help("Move later")
            }

            Button {
                popOut(asset)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Open in its own window")

            Button {
                isChoosingFile = true
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .help("Replace")

            #if canImport(AppKit)
            Button {
                if let url = asset.fileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            } label: {
                Image(systemName: "folder")
            }
            .help("Show in Finder")
            #endif

            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .help("Remove")
            }
        }
        .font(.caption)
        .buttonStyle(.borderless)
        .padding(6)
        .background(Capsule().fill(.ultraThinMaterial))
        .padding(8)
    }

    private func caption(_ asset: MediaAsset) -> some View {
        let details = [
            asset.durationDescription,
            MediaStore.fileSizeDescription(atPath: asset.localPath)
        ]
            .compactMap { $0 }
            .joined(separator: " · ")

        return VStack(alignment: .leading, spacing: 1) {
            Text(asset.displayName)
                .font(.caption2)
                .lineLimit(1)
            if !details.isEmpty {
                Text(details)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(.ultraThinMaterial))
        .padding(8)
    }

    // MARK: Actions

    private func popOut(_ asset: MediaAsset) {
        MediaPreviewWindowController.show(asset: asset)
    }
}
