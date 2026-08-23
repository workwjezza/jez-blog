# TestFlight Setup & Build Fix

## Fix Build Error: "Entitlements require signing"

The build is failing because App Groups require code signing. You have two options:

### Option 1: Select Your Development Team (Recommended for TestFlight)

1. Open `JezBlog.xcodeproj` in Xcode
2. Select the **JezBlog** target
3. Go to the **Signing & Capabilities** tab
4. Under **Team**, select your Apple Developer account
5. The bundle identifier should be `com.jezblog.app`
6. Build again (⌘R)

### Option 2: Disable App Groups for Local Development (Quick Fix)

If you just want to run locally without TestFlight:

1. In Xcode, select the **JezBlog** target
2. Go to **Signing & Capabilities**
3. Find **App Groups** and click the **X** to remove it temporarily
4. Build again

Note: Without App Groups, macOS and iOS won't share data. Re-enable before TestFlight.

---

## TestFlight Checklist

### 1. Apple Developer Portal Setup

1. Go to [developer.apple.com](https://developer.apple.com)
2. **Identifiers** → Create App ID
   - Bundle ID: `com.jezblog.app`
   - Enable: App Groups
3. **Identifiers** → **App Groups** → Create
   - ID: `group.com.jezblog.shared`
   - Name: JezBlog Shared
4. Edit your App ID → Add the App Group
5. **Profiles** → Create provisioning profiles for both macOS and iOS

### 2. Xcode Project Setup

1. Open JezBlog.xcodeproj
2. Select JezBlog target → **Signing & Capabilities**
3. **Team**: Select your account
4. **Bundle Identifier**: `com.jezblog.app`
5. **App Groups**: Enable and check `group.com.jezblog.shared`
6. Verify entitlements files are selected:
   - Debug/Release: `JezBlog/JezBlog.entitlements`

### 3. Build & Archive

```bash
# Build for iOS
xcodebuild -project JezBlog.xcodeproj \
  -scheme JezBlog \
  -destination 'generic/platform=iOS' \
  archive -archivePath build/JezBlog-iOS.xcarchive

# Build for macOS  
xcodebuild -project JezBlog.xcodeproj \
  -scheme JezBlog \
  -destination 'generic/platform=macOS' \
  archive -archivePath build/JezBlog-macOS.xcarchive
```

Or use Xcode:
1. **Product** → **Archive**
2. Select archive in Organizer
3. **Distribute App** → **App Store Connect** → **Upload**

### 4. App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. **My Apps** → **+** → **New App**
3. Fill in:
   - Name: JezBlog
   - Bundle ID: `com.jezblog.app`
   - SKU: jezblog-001
   - Full Access: Yes
4. **TestFlight** tab → Add internal testers
5. Wait for processing (usually 10-30 minutes)

---

## Troubleshooting

### "App Groups container not found"
The app gracefully falls back to local storage. Data won't sync between macOS/iOS until App Groups are properly configured with a provisioning profile.

### "Provisioning profile doesn't include App Groups"
1. Go to developer.apple.com
2. Edit your provisioning profile
3. Select the App Group
4. Download and install the new profile
5. In Xcode: **Preferences** → **Accounts** → **Download Manual Profiles**

### Build succeeds but data doesn't sync
- Verify both macOS and iOS apps use the same Bundle ID
- Check that App Group `group.com.jezblog.shared` is enabled in both apps
- Ensure both are signed with the same Team
