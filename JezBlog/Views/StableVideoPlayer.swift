//
//  StableVideoPlayer.swift
//  jez-blog
//
//  A macOS-stable wrapper around AVPlayerView to avoid SwiftUI VideoPlayer crashes.
//

import AVKit
import AppKit
import SwiftUI

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
