//
//  PlatformCompat.swift
//  jez-blog
//
//  Platform compatibility layer for macOS and iOS.
//

import SwiftUI
import Foundation

#if canImport(UIKit)
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

// MARK: - UIKit Type Aliases
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
public typealias PlatformViewController = UIViewController

// MARK: - Image Extensions
public extension UIImage {
    func pngData() -> Data? {
        return self.pngData()
    }
}

#elseif canImport(AppKit)
import AppKit

// MARK: - AppKit Type Aliases
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
public typealias PlatformViewController = NSViewController

// MARK: - NSImage Extensions
public extension NSImage {
    func pngData() -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}

#endif

// MARK: - Platform-Specific Helpers
public enum PlatformCompat {
    
    /// Returns the appropriate application support directory for the platform
    public static var applicationSupportDirectory: URL {
        #if os(iOS)
        // On iOS, use the app group container if available, otherwise use app's container
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupURL
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #else
        // On macOS, use the app group container if available for shared data
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupURL
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        #endif
    }
    
    /// The app group identifier for shared data between macOS and iOS
    public static let appGroupIdentifier = "group.com.jezblog.shared"
    
    /// Returns the shared container URL for SwiftData and media storage
    public static var sharedContainerURL: URL {
        #if os(iOS)
        // iOS: Use app group container
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupURL
        }
        // Fallback to documents directory
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #else
        // macOS: Use app group container for shared data
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupURL.appendingPathComponent("SharedData", isDirectory: true)
        }
        // Fallback to Application Support
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("JezBlog", isDirectory: true)
        #endif
    }
    
    /// Opens a URL in the platform-appropriate way
    public static func openURL(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
    
    /// Presents a share sheet (iOS) or share picker (macOS)
    @MainActor
    public static func shareItems(_ items: [Any], from view: Any? = nil) {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else { return }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // For iPad popover presentation
        if let popover = activityVC.popoverPresentationController,
           let sourceView = view as? UIView {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        
        rootViewController.present(activityVC, animated: true)
        #else
        let picker = NSSharingServicePicker(items: items)
        if let view = view as? NSView {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
        #endif
    }
}

// MARK: - View Extensions
public extension View {
    /// Platform-appropriate corner radius style
    func platformCornerRadius(_ radius: CGFloat) -> some View {
        #if os(iOS)
        return self.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        #else
        return self.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        #endif
    }
}

// MARK: - Keyboard Handling
#if os(iOS)
public extension View {
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
#endif
