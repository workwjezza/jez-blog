# jez-blog

A native **media garden** — a calm, three-pane place to grow personal posts.
Built with SwiftUI + SwiftData for macOS 14+ and iOS 17+.

![type](https://img.shields.io/badge/platform-macOS%2014%2B%20%7C%20iOS%2017%2B-black) ![swift](https://img.shields.io/badge/Swift-5.9-orange)

## Open it

```bash
open JezBlog.xcodeproj
```

Then press **⌘R**.

## The window

| Pane | Width | What it does |
| --- | --- | --- |
| **Sidebar** | 250 | New Post menu, collections (All / Threads / Media / Links / Unpublished) with live counts, collapsible tag list |
| **Timeline** | 400 | Search field, scrollable post cards showing type, excerpt, tags, block/media counts |
| **Editor** | 800 | Publish toggle, slug, relative edit time, tag editor, delete — plus the editor for the post's type |

## Post types

The type is **inferred from content** (`Post.displayType`), so a post reshapes itself as you
work. A freshly created post remembers the type you asked for until content decides otherwise.

- **Thread** — 2–4 text blocks
- **Media Arrangement** — 1–4 images in a grid, with a double-width feature tile
- **Short + Image** — one block of text beside one image
- **Video Clip** — one video (poster frame + duration) with a caption
- **Link Card** — URL, fetched preview, and a line of your own

All five are live: drag files in, or use the picker; assets are copied into the app's
container so posts never break when the original moves.

## Media handling

`Support/MediaStore.swift` owns everything on disk:

- Drag-and-drop or **Choose File…** for images, video and audio
- Files are copied to the shared App Group container for cross-platform access
- QuickLook-quality thumbnails, video poster frames and durations via AVFoundation
- Alt text per asset (used by the export), plus reorder / replace / remove
- Deleting an asset also deletes its copied file

## Link previews

`Support/LinkMetadataService.swift` fetches a page and reads Open Graph / Twitter /
`<title>` tags, filling in the card's title, description and image. The fields stay
editable — the fetch is a starting point, not the last word.

## Static export

**File ▸ Export Site…** (⇧⌘E) or the toolbar button writes every post with
`publishToWeb` turned on:

```
chosen-folder/
├── index.html          # the timeline, newest first
├── style.css           # serif type, system blue accents, dark-mode aware
├── posts/<slug>.html   # one page per post
└── media/…             # only the assets those posts use
```

Slugs come from `webSlug` (or the title), duplicates get a numeric suffix, and missing
files are skipped and reported rather than failing the whole export.

## Keyboard

| Shortcut | Action |
| --- | --- |
| ⌘N | New thread |
| ⇧⌘↩ | Add block to the open thread |
| ⇧⌘E | Export site |
| File ▸ New Post of Type | Any of the five types |

## Design tokens

Everything visual lives in `JezBlog/Support/Theme.swift`.

- Accent is the **system blue** (`Color.accentColor`, backed by `Assets.xcassets/AccentColor`), so it follows the user's chosen highlight colour
- Sidebar and toolbar on `.ultraThinMaterial`
- Cards on `Color.primary.opacity(0.05)`, 12pt continuous corners, hover-reactive shadow
- Content is `.fontDesign(.serif)`; UI chrome stays system
- One motion signature: spring `response 0.3, damping 0.8`

## Layout

```
JezBlog/
├── JezBlogApp.swift              # @main, ModelContainer, ⌘N / ⇧⌘E commands
├── Models/                       # Post, ContentBlock, MediaAsset, Enums
├── Support/
│   ├── PlatformCompat.swift      # Cross-platform compatibility layer
│   ├── Theme.swift               # colors, motion, CardSurface, DropZone
│   ├── MediaStore.swift          # import, thumbnails, durations, deletion
│   ├── LinkMetadataService.swift # Open Graph / Twitter card scraping
│   └── SiteExporter.swift        # static HTML + CSS + media
└── Views/
    ├── ThreePaneView.swift       # NavigationSplitView, filtering, export
    ├── SidebarView / TimelineView / PostPreviewRow / TagChipView
    ├── DetailContainerView / PostToolbarView / EmptyStateView
    └── Editors/
        ├── ThreadComposerView.swift + BlockCardView.swift
        ├── MediaSlotView.swift   # shared drop target + thumbnail tile
        └── MediaArrangementView / ShortImageView / VideoClipView / LinkCardView
```

Data persists automatically to a SwiftData store in the shared App Group container,
enabling seamless data sharing between macOS and iOS.

## Cross-Platform Support

JezBlog now supports both macOS and iOS with shared data via App Groups:

- **Shared Container**: Data is stored in `group.com.jezblog.shared`
- **SwiftData**: Both platforms use the same database file
- **Media**: Imported media is accessible on both platforms
- **PlatformCompat.swift**: Handles platform-specific differences

## TestFlight Preparation

To prepare the app for TestFlight distribution:

### 1. App Store Connect Setup

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Create a new app with:
   - **Bundle ID**: `com.jezblog.app` (must match your project)
   - **Platform**: iOS and/or macOS
   - **App Group**: `group.com.jezblog.shared`

### 2. Configure App Groups

1. In your Apple Developer account, go to **Identifiers** > **App Groups**
2. Create an App Group with ID: `group.com.jezblog.shared`
3. Add this App Group to both your macOS and iOS App IDs

### 3. Update Project Settings

1. Open `JezBlog.xcodeproj` in Xcode
2. Select the JezBlog target
3. Go to **Signing & Capabilities**:
   - Set your **Team**
   - Set **Bundle Identifier**: `com.jezblog.app`
   - Enable **App Groups** capability
   - Select `group.com.jezblog.shared`

### 4. Build and Archive

```bash
# For iOS
xcodebuild -project JezBlog.xcodeproj -scheme JezBlog -destination 'generic/platform=iOS' archive -archivePath build/JezBlog-iOS.xcarchive

# For macOS
xcodebuild -project JezBlog.xcodeproj -scheme JezBlog -destination 'generic/platform=macOS' archive -archivePath build/JezBlog-macOS.xcarchive
```

### 5. Upload to App Store Connect

1. Open Xcode
2. Go to **Window** > **Organizer**
3. Select your archive
4. Click **Distribute App**
5. Choose **App Store Connect** > **Upload**
6. Select **TestFlight & App Store**

### 6. Configure TestFlight

1. In App Store Connect, go to your app
2. Select **TestFlight** tab
3. Add internal or external testers
4. The build will appear once processing is complete

## Known Limitations

- **macOS**: Uses NSOpenPanel for export folder selection
- **iOS**: Exports to Documents folder with share sheet
- **Drag & Drop**: macOS supports file drag; iOS uses photo picker

## Next

- CloudKit sync for the `cloudKitRecordID` fields
- Richer grid spans in the media arrangement
- Export theme picker
- iPad-optimized UI with multi-window support
