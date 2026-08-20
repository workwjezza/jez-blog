//
//  jez_blogApp.swift
//  jez-blog
//
//  Main app entry point
//

import SwiftUI
import SwiftData

@main
struct jez_blogApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Post.self,
            ContentBlock.self,
            MediaAsset.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ThreePaneView()
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Post") {
                    NotificationCenter.default.post(name: NSNotification.Name("CreateNewPost"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
