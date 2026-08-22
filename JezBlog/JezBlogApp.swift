//
//  JezBlogApp.swift
//  jez-blog
//
//  A media garden for personal content creation.
//

import SwiftUI
import SwiftData

@main
struct JezBlogApp: App {

    /// The SwiftData stack. Persists automatically to the app's container.
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            Post.self,
            ContentBlock.self,
            MediaAsset.self,
            Folder.self
        ])

        let configuration = ModelConfiguration(
            "JezBlogStore",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // If the on-disk store cannot be opened (e.g. an incompatible older
            // schema during development) fall back to memory so the app still runs.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            modelContainer = try! ModelContainer(for: schema, configurations: [fallback])
            print("⚠️ jez-blog: falling back to an in-memory store — \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ThreePaneView()
                .tint(Theme.accent)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Post") {
                    NewPostRequest.send(.thread)
                }
                .keyboardShortcut("n", modifiers: .command)

                Menu("New Post of Type") {
                    ForEach(PostDisplayType.allCases) { type in
                        Button {
                            NewPostRequest.send(type)
                        } label: {
                            Label(type.label, systemImage: type.symbolName)
                        }
                    }
                }
            }

            CommandGroup(after: .saveItem) {
                Button("Export Site…") {
                    NotificationCenter.default.post(name: .exportSiteRequested, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}

/// Bridges menu commands (which sit outside the view hierarchy) to the window
/// that owns the SwiftData context.
enum NewPostRequest {
    static func send(_ type: PostDisplayType) {
        NotificationCenter.default.post(
            name: .newPostRequested,
            object: nil,
            userInfo: ["type": type.rawValue]
        )
    }

    static func type(from notification: Notification) -> PostDisplayType {
        guard
            let raw = notification.userInfo?["type"] as? String,
            let type = PostDisplayType(rawValue: raw)
        else { return .thread }
        return type
    }
}
