# jez-blog

A native macOS **media garden** — a calm, three-pane place to grow personal posts.
Built with SwiftUI + SwiftData for macOS 14+.

![type](https://img.shields.io/badge/platform-macOS%2014%2B-black) ![swift](https://img.shields.io/badge/Swift-5.9-orange)

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
- Files are copied to `Application Support/JezBlogMedia/<uuid>.<ext>`
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

- Accent is the **macOS system blue** (`Color.accentColor`, backed by `Assets.xcassets/AccentColor`), so it follows the user's chosen highlight colour
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

Data persists automatically to a SwiftData store in the app's sandbox container.

## Next

CloudKit sync for the `cloudKitRecordID` fields, richer grid spans in the media
arrangement, and an export theme picker.
