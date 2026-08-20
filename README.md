# jez-blog

A native macOS blogging application built with SwiftUI and SwiftData. This is a "media garden" for personal content creation with a luxurious, inspiring interface.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-green)
![SwiftData](https://img.shields.io/badge/SwiftData-Persistence-purple)

## ✨ Features

### Fully Implemented
- **Three-Pane Layout**: Sidebar, Timeline, and Detail Editor
- **Thread Composer**: Fully functional multi-block text editor with:
  - Add, insert, delete, and reorder blocks
  - Character counting with visual limits (280 chars)
  - Smooth spring animations
  - Hover-based controls
  - Focus indicators
- **SwiftData Persistence**: Auto-saves all changes
- **Search & Filter**: Real-time search across posts
- **Collections**: Filter by All, Threads, Media, Links, Unpublished
- **Publish Toggle**: Mark posts for web publishing
- **Tag System**: Automatic tag aggregation and filtering

### Placeholder Editors (Future Implementation)
- Media Arrangement (2x2 grid of images)
- Short + Image (text with single image)
- Video Clip (video with caption)
- Link Card (URL with preview and commentary)

## 🎨 Design

- **Accent Color**: #FF6B35 (warm orange)
- **Typography**: Serif for content, system for UI
- **Animations**: Spring-based (response: 0.3, dampingFraction: 0.8)
- **Window Size**: 1400×900 pixels
- **Materials**: Ultra-thin material for sidebar

## 🏗️ Architecture

### Data Models (SwiftData)
- **Post**: Main content container with computed display type
- **ContentBlock**: Text/embed blocks with character limits
- **MediaAsset**: Images, videos, and link previews
- **Enums**: PostDisplayType, BlockType, AssetType

### View Hierarchy
```
ThreePaneView (NavigationSplitView)
├── SidebarView
│   ├── New Post Menu
│   ├── Collections
│   └── Tags
├── TimelineView
│   ├── Search Bar
│   └── PostPreviewRow (list)
└── DetailContainerView
    ├── PostToolbarView
    └── Editor (switches based on post type)
        ├── ThreadComposerView ⭐
        ├── MediaArrangementView
        ├── ShortImageView
        ├── VideoClipView
        └── LinkCardView
```

## 🚀 Getting Started

**⚠️ IMPORTANT**: This is NOT a Swift Package. You must create a proper Xcode macOS App project.

See **[SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md)** for detailed setup steps.

### Quick Start

1. Open Xcode
2. Create New Project → macOS → App
3. Configure: SwiftUI + SwiftData
4. Delete auto-generated files
5. Drag source files into Xcode
6. Build and Run (⌘R)

## 📁 Project Structure

```
jez-blog/
├── Models/
│   ├── Enums.swift              # Enumerations and structs
│   ├── Post.swift               # Main post model
│   ├── ContentBlock.swift       # Text block model
│   └── MediaAsset.swift         # Media asset model
├── Views/
│   ├── MainWindow/
│   │   ├── ThreePaneView.swift       # Root layout
│   │   ├── SidebarView.swift         # Collections & tags
│   │   ├── TimelineView.swift        # Post list
│   │   ├── DetailContainerView.swift # Editor container
│   │   └── PostToolbarView.swift     # Toolbar controls
│   ├── Editors/
│   │   ├── ThreadComposerView.swift  # ⭐ Main editor
│   │   ├── MediaArrangementView.swift
│   │   ├── ShortImageView.swift
│   │   ├── VideoClipView.swift
│   │   └── LinkCardView.swift
│   └── Components/
│       ├── BlockCardView.swift       # Individual block
│       ├── PostPreviewRow.swift      # Timeline item
│       └── TagChipView.swift         # Tag display
├── Assets.xcassets/
│   ├── AccentColor.colorset/    # #FF6B35
│   └── AppIcon.appiconset/
├── jez_blogApp.swift            # App entry point
├── SETUP_INSTRUCTIONS.md        # Detailed setup guide
└── README.md                    # This file
```

## 🎯 Usage

### Creating Posts

1. Click **"New Post"** in the sidebar
2. Choose post type:
   - **Thread**: Multi-block text posts
   - **Media Arrangement**: 2x2 image grid
   - **Short + Image**: Text with single image
   - **Video Clip**: Video with caption
   - **Link Card**: URL with preview

### Thread Composer

The star feature! Create multi-block text posts:

- **Add Block**: Click "Add Block" button
- **Insert Block**: Click "+" between blocks
- **Reorder**: Hover and use arrow buttons
- **Delete**: Hover and click trash icon
- **Character Limit**: Visual counter shows 280 char limit
- **Auto-save**: Changes save automatically

### Organizing Posts

- **Search**: Type in timeline search bar
- **Filter by Collection**: Click collections in sidebar
- **Filter by Tag**: Click tags in sidebar
- **Publish**: Toggle "Publish to Web" in toolbar
- **Delete**: Click delete button in toolbar

## 🛠️ Technical Details

### Requirements
- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

### Key Technologies
- **SwiftUI**: Native UI framework
- **SwiftData**: Persistence layer
- **NavigationSplitView**: Three-pane layout
- **@Model**: SwiftData models
- **@Query**: Reactive data queries
- **@Relationship**: Model relationships

### Design Patterns
- **MVVM**: Model-View-ViewModel architecture
- **Computed Properties**: Dynamic display type detection
- **Cascade Delete**: Automatic cleanup of relationships
- **Reactive Updates**: SwiftData auto-updates views

## 🎨 Customization

### Accent Color
Edit `Assets.xcassets/AccentColor.colorset/Contents.json`:
```json
"red" : "1.000",
"green" : "0.420",
"blue" : "0.208"
```

### Character Limits
Edit `ContentBlock.swift`:
```swift
characterLimit: Int? = 280  // Change default limit
```

### Window Size
Edit `jez_blogApp.swift`:
```swift
.defaultSize(width: 1400, height: 900)  // Adjust size
```

## 🐛 Troubleshooting

See **[SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md)** for detailed troubleshooting.

Common issues:
- **No window appears**: You created a Swift Package instead of macOS App
- **Build errors**: Files not added to target
- **Data not persisting**: Check SwiftData configuration

## 🚧 Future Enhancements

- [ ] Implement media upload/handling
- [ ] Add tag management UI
- [ ] Build actual web publishing
- [ ] Add CloudKit sync
- [ ] Export to various formats
- [ ] Rich text formatting
- [ ] Image editing tools
- [ ] Video trimming
- [ ] Link preview fetching
- [ ] Keyboard shortcuts
- [ ] Dark mode optimization
- [ ] Accessibility improvements

## 📝 License

This project is provided as-is for personal use and learning.

## 🙏 Acknowledgments

Built with lessons learned from previous attempts. Key insights:
- ✅ Use Xcode macOS App projects, not Swift Packages
- ✅ Include all three parameters in `.navigationSplitViewColumnWidth()`
- ✅ Avoid problematic window modifiers like `.windowStyle(.hiddenTitleBar)`
- ✅ Focus on making the Thread Composer feel amazing

---

**Happy blogging! 🌱**
