//
//  MediaArrangementView.swift
//  jez-blog
//
//  Multiple images, arranged in a grid. Drop them in from Finder or browse.
//

import SwiftData
import SwiftUI

struct MediaArrangementView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var post: Post

    @State private var isChoosingFiles = false
    @State private var message: String?

    /// Maximum number of images supported
    static let maxImages = 25

    private var editor: MediaEditor { MediaEditor(post: post, context: modelContext) }
    private var images: [MediaAsset] { post.sortedAssets.filter { $0.assetType == .image } }
    private var remaining: Int { max(0, Self.maxImages - images.count) }
    private var isFeatureLayout: Bool { images.first?.isFeatureTile ?? false }

    /// Dynamic columns based on image count - more images = more columns
    private var columns: [GridItem] {
        let count = images.count
        let columnCount: Int
        if count <= 4 {
            columnCount = 2
        } else if count <= 9 {
            columnCount = 3
        } else {
            columnCount = 4
        }
        return Array(repeating: GridItem(.flexible(), spacing: Theme.componentSpacing), count: columnCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            EditorHeader(
                title: "Media Arrangement",
                subtitle: "\(images.count) of \(Self.maxImages) images · drag files straight in from Finder"
            ) {
                Button {
                    isChoosingFiles = true
                } label: {
                    Label("Add Images", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(remaining == 0)
                .help(remaining == 0 ? "\(Self.maxImages) images is the maximum" : "Choose images to add")
            }

            // Only show layout picker for 2-4 images (feature layout doesn't make sense for larger galleries)
            if images.count >= 2 && images.count <= 4 { layoutPicker }

            grid

            CaptionCardView(
                post: post,
                title: "Caption",
                placeholder: "A line about these pictures…",
                addLabel: "Add a caption",
                addHint: "Optional — the pictures can speak for themselves"
            )

            if let message { messageRow(message) }

        }
        .fileImporter(
            isPresented: $isChoosingFiles,
            allowedContentTypes: MediaStore.imageContentTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result { importImages(urls) }
        }
    }


    // MARK: - Layout

    private var layoutPicker: some View {
        Picker("Layout", selection: Binding(get: { isFeatureLayout }, set: setFeatureLayout)) {
            Text("Even grid").tag(false)
            Text("Feature first").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 260)
        .help("How the images sit together, here and on the web")
    }

    @ViewBuilder
    private var grid: some View {
        VStack(spacing: Theme.componentSpacing) {
            if isFeatureLayout, let feature = images.first {
                slot(for: feature, index: 0, height: 300)

                LazyVGrid(columns: columns, spacing: Theme.componentSpacing) {
                    ForEach(Array(images.dropFirst().enumerated()), id: \.element.id) { offset, asset in
                        slot(for: asset, index: offset + 1, height: 150)
                    }
                    if remaining > 0 { emptySlot(height: 150) }
                }
            } else {
                LazyVGrid(columns: columns, spacing: Theme.componentSpacing) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, asset in
                        slot(for: asset, index: index, height: 170)
                    }
                    if remaining > 0 { emptySlot(height: 170) }
                }
            }
        }
        .animation(Theme.spring, value: images.map(\.id))
        .animation(Theme.spring, value: isFeatureLayout)
    }

    private func slot(for asset: MediaAsset, index: Int, height: CGFloat) -> some View {
        MediaSlotView(
            asset: asset,
            kind: .image,
            height: height,
            showsAltText: true,
            badge: "\(index + 1)",
            canMoveEarlier: index > 0,
            canMoveLater: index < images.count - 1,
            onImport: { urls in replace(asset, with: urls) },
            onRemove: {
                message = nil
                editor.remove(asset)
            },
            onMoveEarlier: { editor.move(asset, by: -1) },
            onMoveLater: { editor.move(asset, by: 1) }
        )
        .transition(Theme.cardTransition)
    }

    private func emptySlot(height: CGFloat) -> some View {
        MediaSlotView(
            kind: .image,
            emptySymbol: "photo.badge.plus",
            emptyTitle: images.isEmpty ? "Drop images here" : "Add another",
            emptySubtitle: "\(remaining) slot\(remaining == 1 ? "" : "s") left",
            height: height,
            allowsMultiple: true,
            onImport: importImages
        )
        .transition(Theme.cardTransition)
    }

    private func messageRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
            Text(text)
            Spacer()
            Button("Dismiss") { withAnimation(Theme.hover) { message = nil } }
                .buttonStyle(.borderless)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .transition(.opacity)
    }

    // MARK: - Actions

    private func importImages(_ urls: [URL]) {
        withAnimation(Theme.spring) {
            message = editor.importFiles(urls, kind: .image, limit: remaining)
        }
    }

    /// Swaps one image for another, keeping its place in the arrangement.
    private func replace(_ asset: MediaAsset, with urls: [URL]) {
        guard let replacement = urls.first else { return }

        let position = asset.orderIndex
        let wasFeature = asset.isFeatureTile

        editor.remove(asset)
        message = editor.importFiles([replacement], kind: .image, limit: 1)

        guard let inserted = post.sortedAssets.last else { return }
        for other in post.sortedAssets where other.id != inserted.id && other.orderIndex >= position {
            other.orderIndex += 1
        }
        inserted.orderIndex = position
        inserted.isFeatureTile = wasFeature
        editor.reindex()
    }

    private func setFeatureLayout(_ isOn: Bool) {
        withAnimation(Theme.spring) {
            for (index, asset) in images.enumerated() {
                asset.isFeatureTile = isOn && index == 0
            }
            post.touch()
        }
    }
}
