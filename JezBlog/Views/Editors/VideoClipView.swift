//
//  VideoClipView.swift
//  jez-blog
//
//  A single clip with a caption — playable right here in the editor.
//

import AVKit
#if canImport(AppKit)
import AppKit
#endif
import SwiftData
import SwiftUI

struct VideoClipView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var post: Post

    @State private var player: AVPlayer?
    @State private var message: String?
    @State private var isRenamingFile: Bool = false
    @State private var renameText: String = ""

    private var editor: MediaEditor { MediaEditor(post: post, context: modelContext) }
    private var clip: MediaAsset? { post.sortedAssets.first { $0.assetType == .video } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            EditorHeader(
                title: "Video Clip",
                subtitle: clip == nil
                    ? "One moving image — words optional"
                    : "Scrub it here before it goes out"
            ) {
                if let clip {
                    HStack(spacing: 8) {
                        Button {
                            MediaPreviewWindowController.show(asset: clip)
                        } label: {
                            Label("Open", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                        .help("Open the clip in its own window")

                        Button(role: .destructive) {
                            remove(clip)
                        } label: {
                            Label("Remove Clip", systemImage: "trash")
                        }
                    }
                }
            }


            if let clip, clip.hasContent {
                playerCard(clip)
            } else {
                MediaSlotView(
                    kind: .video,
                    emptySymbol: "film.stack",
                    emptyTitle: "Drop a video",
                    emptySubtitle: "MP4 or MOV — or click to choose",
                    height: 280,
                    onImport: importClip
                )
            }

            CaptionCardView(
                post: post,
                title: "Caption",
                placeholder: "What are we looking at?",
                addLabel: "Add a caption",
                addHint: "Optional — the clip can speak for itself"
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
        .animation(Theme.spring, value: clip?.id)
    }

    // MARK: - Player

    private func playerCard(_ clip: MediaAsset) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Color.black

                if !clip.fileExists {
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                        Text("The file has moved or been deleted.")
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                } else if let player {
                    StableVideoPlayer(player: player)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                        .fixedSize()
                }
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )

            HStack(spacing: 12) {
                if isRenamingFile {
                    HStack(spacing: 6) {
                        Image(systemName: "film")
                        TextField("Filename", text: $renameText)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .onSubmit { commitRename(clip) }
                        
                        Button("Save") { commitRename(clip) }
                            .buttonStyle(.borderless)
                        Button("Cancel") {
                            isRenamingFile = false
                            renameText = ""
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Label(clip.displayName, systemImage: "film")
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            startRename(clip)
                        }
                        .help("Double-click to rename")
                }

                if !isRenamingFile {
                    if let duration = clip.durationDescription {
                        Text(duration).monospacedDigit()
                    }
                    if let size = MediaStore.fileSizeDescription(atPath: clip.localPath) {
                        Text(size)
                    }

                    Spacer()

                    #if canImport(AppKit)
                    if let url = clip.fileURL {
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        .buttonStyle(.borderless)
                    }
                    #endif
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .task(id: clip.localPath) {
            guard let path = clip.localPath, clip.fileExists else {
                player = nil
                return
            }
            let newPlayer = AVPlayer(url: URL(fileURLWithPath: path))
            
            // Enable looping
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { _ in
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }
            
            player = newPlayer
            await editor.loadDuration(for: clip)
        }
    }

    // MARK: - Actions


    private func importClip(_ urls: [URL]) {
        withAnimation(Theme.spring) {
            message = editor.replaceSingle(kind: .video, with: urls)
        }
    }

    private func remove(_ clip: MediaAsset) {
        player?.pause()
        player = nil
        editor.remove(clip)
    }

    private func startRename(_ clip: MediaAsset) {
        guard let url = clip.fileURL else { return }
        renameText = url.deletingPathExtension().lastPathComponent
        isRenamingFile = true
    }

    private func commitRename(_ clip: MediaAsset) {
        guard !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let oldPath = clip.localPath else {
            isRenamingFile = false
            renameText = ""
            return
        }

        if let newPath = MediaStore.renameFile(atPath: oldPath, to: renameText) {
            clip.localPath = newPath
            post.touch()
        }

        isRenamingFile = false
        renameText = ""
    }
}
