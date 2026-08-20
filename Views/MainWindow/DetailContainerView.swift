//
//  DetailContainerView.swift
//  jez-blog
//
//  Detail container that switches editors based on post type
//

import SwiftUI

struct DetailContainerView: View {
    let post: Post?
    
    var body: some View {
        if let post = post {
            VStack(spacing: 0) {
                PostToolbarView(post: post)
                
                Divider()
                
                ScrollView {
                    editorForPost(post)
                        .padding()
                }
            }
        } else {
            ContentUnavailableView(
                "No Post Selected",
                systemImage: "doc.text",
                description: Text("Select a post from the timeline to edit")
            )
        }
    }
    
    @ViewBuilder
    private func editorForPost(_ post: Post) -> some View {
        switch post.displayType {
        case .thread:
            ThreadComposerView(post: post)
        case .mediaArrangement:
            MediaArrangementView(post: post)
        case .shortWithImage:
            ShortImageView(post: post)
        case .videoClip:
            VideoClipView(post: post)
        case .linkCard:
            LinkCardView(post: post)
        }
    }
}
