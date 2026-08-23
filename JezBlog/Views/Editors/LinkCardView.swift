//
//  LinkCardView.swift
//  jez-blog
//
//  Paste a link, fetch its preview, add a line of your own.
//

import SwiftData
import SwiftUI

struct LinkCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Bindable var post: Post

    @State private var urlString = ""
    @State private var isFetching = false
    @State private var message: String?
    @State private var hasLoadedField = false

    private var asset: MediaAsset? { post.sortedAssets.first { $0.assetType == .linkPreview } }
    private var canFetch: Bool { LinkMetadataService.normalizedURL(from: urlString) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            EditorHeader(
                title: "Link Card",
                subtitle: "Something worth passing on"
            ) {
                Button {
                    Task { await fetchMetadata() }
                } label: {
                    if isFetching {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                            .fixedSize()
                    } else {
                        Label("Fetch Preview", systemImage: "arrow.down.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!canFetch || isFetching)
                .help("Read the page's title, description and image")
            }

            addressField

            if let asset, asset.url != nil {
                previewCard(asset)
            } else {
                DropZone(
                    symbolName: "link",
                    title: "Paste a link above",
                    subtitle: "Then fetch its preview, or write the card by hand",
                    minHeight: 120
                )
            }

            commentaryCard

            if let messageText = message {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(verbatim: messageText)
                    Spacer()
                    Button("Dismiss") { withAnimation(Theme.hover) { message = nil } }
                        .buttonStyle(.borderless)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .transition(.opacity)
            }
        }
        .animation(Theme.spring, value: asset?.previewTitle)
        .onAppear {
            guard !hasLoadedField else { return }
            urlString = asset?.url?.absoluteString ?? ""
            hasLoadedField = true
        }
    }

    // MARK: - Address

    private var addressField: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .foregroundStyle(.secondary)

            TextField("https://…", text: $urlString)
                .textFieldStyle(.plain)
                .font(.body.monospaced())
                .onSubmit { Task { await fetchMetadata() } }

            if !urlString.isEmpty {
                Button {
                    urlString = ""
                    message = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.tertiary)
                .help("Clear")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .cardSurface(isHighlighted: canFetch)
        .onChange(of: urlString) { _, _ in storeURL() }
    }

    // MARK: - Preview

    private func previewCard(_ asset: MediaAsset) -> some View {
        let bindable = Bindable(asset)

        return HStack(alignment: .top, spacing: Theme.componentSpacing) {
            thumbnail(for: asset)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Title", text: bindable.previewTitle.orEmpty)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .fontDesign(.serif)

                TextField("Description", text: bindable.previewDescription.orEmpty, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1...4)

                HStack(spacing: 8) {
                    if let host = asset.url?.host() {
                        Text(host)
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }

                    Spacer()

                    if let url = asset.url {
                        Button("Open") { openURL(url) }
                            .buttonStyle(.borderless)
                            .font(.caption)
                    }

                    Button(role: .destructive) {
                        MediaEditor(post: post, context: modelContext).remove(asset)
                        urlString = ""
                    } label: {
                        Text("Remove")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
        }
        .padding(Theme.cardPadding)
        .cardSurface()
        .onChange(of: asset.previewTitle) { _, _ in post.touch() }
        .onChange(of: asset.previewDescription) { _, _ in post.touch() }
        .transition(Theme.cardTransition)
    }

    @ViewBuilder
    private func thumbnail(for asset: MediaAsset) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        if let string = asset.previewImageURL, let url = URL(string: string) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "link").foregroundStyle(.secondary)
                default:
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                        .fixedSize()
                }
            }
            .frame(width: 96, height: 96)
            .background(Theme.cardFill)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
        } else {
            shape
                .fill(Theme.cardFill)
                .frame(width: 96, height: 96)
                .overlay(Image(systemName: "link").foregroundStyle(.secondary))
                .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }

    // MARK: - Commentary

    private var commentaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why it matters")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let block = post.sortedBlocks.first {
                let bindable = Bindable(block)

                TextEditor(text: bindable.content)
                    .font(.body)
                    .fontDesign(.serif)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: Theme.minBlockHeight)
                    .overlay(alignment: .topLeading) {
                        if block.content.isEmpty {
                            Text("A sentence of your own…")
                                .font(.body)
                                .fontDesign(.serif)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: block.content) { _, _ in post.touch() }
            } else {
                Button(action: addBlock) {
                    Label("Add commentary", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
                .tint(Theme.accent)
            }
        }
        .padding(Theme.cardPadding)
        .cardSurface()
    }

    // MARK: - Actions

    /// Keeps the stored asset's URL in step with the field.
    private func storeURL() {
        guard let url = LinkMetadataService.normalizedURL(from: urlString) else { return }
        let asset = ensureAsset()
        if asset.url != url {
            asset.url = url
            post.touch()
        }
    }

    private func fetchMetadata() async {
        guard let url = LinkMetadataService.normalizedURL(from: urlString) else {
            message = "That does not look like a web address."
            return
        }

        urlString = url.absoluteString
        let asset = ensureAsset()
        asset.url = url

        isFetching = true
        message = nil

        do {
            let metadata = try await LinkMetadataService.fetch(url)
            withAnimation(Theme.spring) {
                if let title = metadata.title { asset.previewTitle = title }
                if let description = metadata.description { asset.previewDescription = description }
                if let image = metadata.imageURL { asset.previewImageURL = image }
                post.touch()
            }
        } catch {
            message = error.localizedDescription
        }

        isFetching = false
    }

    /// Finds — or creates — the post's single link preview asset.
    private func ensureAsset() -> MediaAsset {
        if let asset { return asset }

        let asset = MediaAsset(
            orderIndex: post.mediaAssets?.count ?? 0,
            assetType: .linkPreview
        )
        modelContext.insert(asset)

        var updated = post.mediaAssets ?? []
        updated.append(asset)
        post.mediaAssets = updated
        post.touch()

        return asset
    }

    private func addBlock() {
        let block = ContentBlock(orderIndex: 0)
        modelContext.insert(block)

        withAnimation(Theme.spring) {
            var updated = post.blocks ?? []
            updated.append(block)
            post.blocks = updated
            post.touch()
        }
    }
}
