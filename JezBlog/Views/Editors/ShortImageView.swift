//
//  ShortImageView.swift
//  jez-blog
//
//  One picture, seen whole — with a thought beside it, if you want one.
//

import SwiftData
import SwiftUI

struct ShortImageView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var post: Post

    @State private var message: String?

    private var editor: MediaEditor { MediaEditor(post: post, context: modelContext) }
    private var image: MediaAsset? { post.sortedAssets.first { $0.assetType == .image } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            EditorHeader(
                title: "Photo",
                subtitle: image == nil
                    ? "A single picture — words optional"
                    : "Click the picture to open it in its own window"
            ) {
                if let image {
                    Button {
                        MediaPreviewWindowController.show(asset: image)
                    } label: {
                        Label("Open", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .help("Open the picture in its own window")
                }
            }

            MediaSlotView(
                asset: image,
                kind: .image,
                emptySymbol: "photo.badge.plus",
                emptyTitle: "Drop an image",
                emptySubtitle: "PNG, JPEG or HEIC — or click to choose",
                height: 520,
                showsAltText: image != nil,
                fitsContent: true,
                onImport: { urls in
                    withAnimation(Theme.spring) {
                        message = editor.replaceSingle(kind: .image, with: urls)
                    }
                },
                onRemove: image == nil ? nil : { if let image { editor.remove(image) } }
            )
            .animation(Theme.spring, value: image?.id)

            CaptionCardView(
                post: post,
                title: "Caption",
                placeholder: "Say it in one breath…",
                addLabel: "Add a caption",
                addHint: "Optional — a picture can stand on its own"
            )

            if let message {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(message)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
