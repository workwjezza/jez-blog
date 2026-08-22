//
//  MediaGalleryView.swift
//  jez-blog
//
//  The Media collection, shown as a simple list to avoid layout issues.
//

import SwiftUI

struct MediaGalleryView: View {
    let posts: [Post]
    @Binding var selectedPost: Post?

    var body: some View {
        List {
            ForEach(posts) { post in
                PostPreviewRow(
                    post: post,
                    isSelected: selectedPost?.id == post.id,
                    onSelect: {
                        withAnimation(Theme.spring) {
                            selectedPost = post
                        }
                    }
                )
            }
        }
        .listStyle(.plain)
        .animation(Theme.spring, value: posts.map(\.id))
    }
}
