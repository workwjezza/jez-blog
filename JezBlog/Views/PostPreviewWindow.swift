//
//  PostPreviewWindow.swift
//  jez-blog
//
//  A post popped out into its own window for focused editing or viewing.
//

import AppKit
import SwiftUI
import SwiftData

// MARK: - Window Controller

/// Opens (and keeps alive) the pop-out post windows.
@MainActor
final class PostPreviewWindowController: NSWindowController, NSWindowDelegate {

    /// Windows currently on screen. Removed again as each one closes.
    private static var live: Set<PostPreviewWindowController> = []

    /// Pops the post out into its own resizable window.
    static func show(post: Post, context: ModelContext) {
        // Don't open duplicate windows for the same post
        if let existing = live.first(where: { ($0.window?.contentViewController as? NSHostingController<PostPreviewWindowView>)?.rootView.post.id == post.id }) {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: PostPreviewWindowView(post: post, context: context))

        let window = NSWindow(contentViewController: hosting)
        window.title = post.previewTitle
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 900, height: 700))
        window.contentMinSize = NSSize(width: 500, height: 400)
        window.isReleasedWhenClosed = false
        window.center()

        let controller = PostPreviewWindowController(window: window)
        window.delegate = controller
        live.insert(controller)

        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)

        // Animate window appearance
        window.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    func windowWillClose(_ notification: Notification) {
        // Fade out before removing
        if let window = window {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().alphaValue = 0
            }
        }
        Self.live.remove(self)
    }
}

// MARK: - Window View

struct PostPreviewWindowView: View {
    @Bindable var post: Post
    let context: ModelContext

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Content
            ScrollView {
                AdaptiveContainerView(post: post)
                    .padding(.vertical, Theme.sectionSpacing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            // Content type icons
            contentTypeIcons

            Spacer()

            // Post info
            Text("Edited \(post.modifiedAt.relativeDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Publish toggle
            Toggle(isOn: Binding(
                get: { post.publishToWeb },
                set: { newValue in
                    withAnimation(Theme.selection) {
                        post.publishToWeb = newValue
                        if newValue, post.webSlug == nil {
                            post.webSlug = PostToolbarView.slug(from: post.previewTitle)
                        }
                        post.touch()
                    }
                }
            )) {
                Text("Publish")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .tint(Theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var contentTypeIcons: some View {
        HStack(spacing: 4) {
            ForEach(post.contentTypeIcons, id: \.self) { iconName in
                Image(systemName: iconName)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

// MARK: - Post Preview Row Extension

extension PostPreviewRow {
    /// Opens this post in a pop-out window.
    func openInWindow(context: ModelContext) {
        PostPreviewWindowController.show(post: post, context: context)
    }
}
