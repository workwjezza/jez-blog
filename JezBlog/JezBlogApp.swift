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

        // Use shared container for cross-platform data sharing
        let sharedURL = PlatformCompat.sharedContainerURL.appendingPathComponent("JezBlog.store", isDirectory: false)
        
        let configuration = ModelConfiguration(
            "JezBlogStore",
            schema: schema,
            url: sharedURL
        )

        do {
            // Ensure the directory exists
            let directory = sharedURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            print("✅ jez-blog: using shared store at \(sharedURL.path)")
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
        #if os(iOS)
        iOSBody
        #else
        macOSBody
        #endif
    }
    
    #if os(iOS)
    @MainActor
    private var iOSBody: some Scene {
        WindowGroup {
            iOSContentView()
        }
        .modelContainer(modelContainer)
    }
    #else
    @MainActor
    private var macOSBody: some Scene {
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
    #endif
}

#if os(iOS)
/// iOS main content view with tab-based navigation
struct iOSContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.createdAt, order: .forward) private var folders: [Folder]
    
    @State private var selectedTab = 0
    @State private var selectedPost: Post?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Posts Tab
            NavigationStack {
                iOSPostsListView()
            }
            .tabItem {
                Label("Posts", systemImage: "doc.text")
            }
            .tag(0)
            
            // Folders Tab
            NavigationStack {
                iOSFoldersListView()
            }
            .tabItem {
                Label("Folders", systemImage: "folder")
            }
            .tag(1)
            
            // Settings Tab
            NavigationStack {
                iOSSettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(2)
        }
        .tint(Theme.accent)
    }
}

/// iOS Posts List View
struct iOSPostsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.createdAt, order: .reverse) private var posts: [Post]
    @State private var showingNewPostSheet = false
    
    var body: some View {
        List(posts) { post in
            NavigationLink(value: post) {
                PostPreviewRow(post: post)
            }
        }
        .navigationTitle("Posts")
        .navigationDestination(for: Post.self) { post in
            iOSPostEditorView(post: post)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewPostSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewPostSheet) {
            iOSNewPostSheet()
        }
    }
}

/// iOS Post Editor View
struct iOSPostEditorView: View {
    @Bindable var post: Post
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            AdaptiveContainerView(post: post)
                .padding(.vertical, Theme.sectionSpacing)
        }
        .navigationTitle(post.previewTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: $post.publishToWeb) {
                    Text("Publish")
                }
                .tint(Theme.accent)
            }
        }
    }
}

/// iOS New Post Sheet
struct iOSNewPostSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(PostDisplayType.allCases) { type in
                Button {
                    let post = Post(displayType: type)
                    post.folder = Folder.defaultFolder(in: modelContext)
                    modelContext.insert(post)
                    dismiss()
                } label: {
                    Label(type.label, systemImage: type.symbolName)
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// iOS Folders List View
struct iOSFoldersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.createdAt, order: .forward) private var folders: [Folder]
    @State private var showingNewFolder = false
    
    var body: some View {
        List {
            ForEach(folders) { folder in
                NavigationLink(value: folder) {
                    FolderRowView(folder: folder)
                }
            }
        }
        .navigationTitle("Folders")
        .navigationDestination(for: Folder.self) { folder in
            iOSFolderDetailView(folder: folder)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
    }
}

/// iOS Folder Row View
struct FolderRowView: View {
    let folder: Folder
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(Theme.accent)
            Text(folder.name)
            Spacer()
            Text("\(folder.posts.count)")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}

/// iOS Folder Detail View
struct iOSFolderDetailView: View {
    let folder: Folder
    
    var body: some View {
        List(folder.posts.sorted(by: { $0.createdAt > $1.createdAt })) { post in
            NavigationLink(value: post) {
                PostPreviewRow(post: post)
            }
        }
        .navigationTitle(folder.name)
        .navigationDestination(for: Post.self) { post in
            iOSPostEditorView(post: post)
        }
    }
}

/// iOS Settings View
struct iOSSettingsView: View {
    var body: some View {
        List {
            Section("About") {
                HStack {
                    Text("JezBlog")
                    Spacer()
                    Text("v1.0")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Data") {
                Text("Shared data storage enabled")
                    .foregroundStyle(.secondary)
                Text("Data syncs between iOS and macOS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

extension Folder {
    static func defaultFolder(in context: ModelContext) -> Folder {
        let descriptor = FetchDescriptor<Folder>(sortBy: [SortDescriptor(\.createdAt)])
        if let first = try? context.fetch(descriptor).first {
            return first
        }
        let folder = Folder(name: "Uncategorized")
        context.insert(folder)
        return folder
    }
}

#endif

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
