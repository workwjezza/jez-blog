# jez-blog Setup Instructions

## ⚠️ CRITICAL: Do NOT Use Swift Package Manager

This project **must** be set up as a proper Xcode macOS App project. Swift Packages cannot display GUI windows on macOS.

## Setup Steps

Follow these steps carefully to create the Xcode project and add the source files:

### 1. Open Xcode

Launch Xcode on your Mac.

### 2. Create New Project

1. Go to **File → New → Project** (or press ⌘⇧N)
2. In the template chooser:
   - Select **macOS** tab at the top
   - Choose **App** template
   - Click **Next**

### 3. Configure Project

Fill in the project details:

- **Product Name**: `jez-blog`
- **Team**: Select your team (or leave as None)
- **Organization Identifier**: Use your reverse domain (e.g., `com.yourname`)
- **Interface**: **SwiftUI** ✅
- **Language**: **Swift** ✅
- **Storage**: **SwiftData** ✅
- **Include Tests**: Optional (unchecked is fine)

Click **Next**.

### 4. Choose Save Location

1. Navigate to a location where you want to save the project
2. **IMPORTANT**: Do NOT save it inside the existing `jez-blog` folder
3. Save it to a temporary location (e.g., Desktop or Documents)
4. Click **Create**

### 5. Delete Auto-Generated Files

Xcode will create some default files that we don't need. Delete these:

1. In the Project Navigator (left sidebar), find and **delete**:
   - `ContentView.swift` (if present)
   - `Item.swift` (if present)
   - The default app file (e.g., `jez_blogApp.swift` if it exists)
   - Any other auto-generated Swift files

2. When prompted, choose **Move to Trash**

### 6. Add Source Files

Now we'll add all the source files from this directory:

1. In Finder, navigate to `/Users/studio-jd/Projects/jez-blog`
2. Select ALL the following items:
   - `Models` folder
   - `Views` folder
   - `Assets.xcassets` folder
   - `jez_blogApp.swift` file

3. **Drag and drop** these items into your Xcode project in the Project Navigator

4. In the dialog that appears, make sure to:
   - ✅ **Check** "Copy items if needed"
   - ✅ Select "Create groups" (not "Create folder references")
   - ✅ Ensure your app target is checked under "Add to targets"
   - Click **Finish**

### 7. Verify File Structure

Your Xcode project should now have this structure:

```
jez-blog
├── jez_blogApp.swift
├── Models/
│   ├── Enums.swift
│   ├── Post.swift
│   ├── ContentBlock.swift
│   └── MediaAsset.swift
├── Views/
│   ├── MainWindow/
│   │   ├── ThreePaneView.swift
│   │   ├── SidebarView.swift
│   │   ├── TimelineView.swift
│   │   ├── DetailContainerView.swift
│   │   └── PostToolbarView.swift
│   ├── Editors/
│   │   ├── ThreadComposerView.swift
│   │   ├── MediaArrangementView.swift
│   │   ├── ShortImageView.swift
│   │   ├── VideoClipView.swift
│   │   └── LinkCardView.swift
│   └── Components/
│       ├── BlockCardView.swift
│       ├── PostPreviewRow.swift
│       └── TagChipView.swift
└── Assets.xcassets/
    ├── AccentColor.colorset/
    ├── AppIcon.appiconset/
    └── Contents.json
```

### 8. Build and Run

1. Select your Mac as the run destination (top toolbar)
2. Press **⌘R** or click the **Play** button
3. The app should build successfully and launch!

## Expected Result

When the app launches, you should see:

- ✅ A window sized 1400×900 pixels
- ✅ Three-pane layout:
  - **Left**: Sidebar with "New Post" menu and collections
  - **Center**: Timeline (empty initially)
  - **Right**: Detail view showing "No Post Selected"

## Testing the App

Try these actions to verify everything works:

1. **Create a Thread Post**:
   - Click "New Post" in the sidebar
   - Select "Thread"
   - A new post appears in the timeline
   - Click it to see the Thread Composer

2. **Add Blocks**:
   - Click "Add Block" button
   - Type some text
   - Watch the character counter
   - Add more blocks with the "+" button between blocks

3. **Reorder Blocks**:
   - Hover over a block to see controls
   - Use arrow buttons to move blocks up/down

4. **Delete Blocks**:
   - Hover over a block
   - Click the trash icon

5. **Publish Toggle**:
   - Toggle "Publish to Web" in the toolbar
   - Notice the globe icon appears in the timeline

6. **Search**:
   - Type in the search bar
   - Posts filter in real-time

7. **Collections**:
   - Click different collections in the sidebar
   - Posts filter by type

## Features Implemented

### ✅ Fully Functional
- Three-pane NavigationSplitView layout
- SwiftData persistence (auto-saves)
- Thread Composer with full CRUD operations
- Character counting with limits
- Block reordering with smooth animations
- Search and filtering
- Collections (All, Threads, Media, Links, Unpublished)
- Publish toggle
- Delete posts
- Hover effects and focus indicators

### 📦 Placeholder (Future Implementation)
- Media Arrangement editor
- Short + Image editor
- Video Clip editor
- Link Card editor
- Tag management (add/remove tags)
- Actual media upload/handling

## Design Specifications

- **Accent Color**: #FF6B35 (warm orange) - RGB(255, 107, 53)
- **Animations**: Spring (response: 0.3, dampingFraction: 0.8)
- **Typography**: Serif for content, system for UI
- **Window Size**: 1400×900 pixels
- **macOS Version**: 14.0+

## Troubleshooting

### Build Errors

If you get build errors:

1. **"Cannot find type 'Post' in scope"**:
   - Make sure all files are added to your app target
   - Check that files appear in Build Phases → Compile Sources

2. **"No such module 'SwiftData'"**:
   - Ensure your deployment target is macOS 14.0 or later
   - Check in Project Settings → General → Minimum Deployments

3. **Asset catalog errors**:
   - Make sure Assets.xcassets is added to your target
   - Check Build Phases → Copy Bundle Resources

### Runtime Issues

If the app builds but doesn't work correctly:

1. **Window doesn't appear**:
   - This is why we don't use Swift Package Manager!
   - Verify you created a macOS App project, not a Swift Package

2. **Data doesn't persist**:
   - SwiftData should work automatically
   - Check Console for any SwiftData errors

3. **Accent color not showing**:
   - Verify AccentColor.colorset is in Assets.xcassets
   - Check the color values in Contents.json

## Next Steps

Once the app is running, you can:

1. **Implement Media Editors**: Add actual functionality to the placeholder editors
2. **Add Tag Management**: Allow users to add/remove tags from posts
3. **Implement Export**: Add functionality to export posts to various formats
4. **Add CloudKit Sync**: Enable syncing across devices
5. **Implement Web Publishing**: Build the actual web publishing feature

## Architecture Notes

- **SwiftData**: Automatic persistence, no manual save needed
- **Three-Pane Layout**: Uses NavigationSplitView with proper column widths
- **Computed Display Type**: Posts automatically determine their type based on content
- **Relationship Management**: Cascade delete ensures cleanup when posts are deleted

## Support

If you encounter issues not covered here, check:

1. Xcode version (should be 15.0+)
2. macOS version (should be 14.0+)
3. All files are properly added to the target
4. No Swift Package Manager files (Package.swift) exist

---

**Enjoy building your media garden! 🌱**
