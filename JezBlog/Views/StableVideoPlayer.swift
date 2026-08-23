//
//  StableVideoPlayer.swift
//  jez-blog
//
//  A cross-platform video player that uses AVPlayerView on macOS
//  and VideoPlayer on iOS.
//

import AVKit
import SwiftUI

#if canImport(AppKit)
import AppKit

/// A stable video player for macOS that uses AVPlayerView directly,
/// avoiding the metadata initialization crashes seen with SwiftUI's VideoPlayer.
struct StableVideoPlayer: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .default
        view.showsSharingServiceButton = false
        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // Only update if the player instance has changed
        if nsView.player !== player {
            nsView.player = player
        }
    }
    
    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player?.pause()
        nsView.player = nil
    }
}

#else

import UIKit

/// iOS video player using SwiftUI's VideoPlayer
struct StableVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: ()) {
        uiViewController.player?.pause()
        uiViewController.player = nil
    }
}

#endif
