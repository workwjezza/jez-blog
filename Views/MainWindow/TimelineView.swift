//
//  TimelineView.swift
//  jez-blog
//
//  Timeline view with search and post list
//

import SwiftUI

struct TimelineView: View {
    let posts: [Post]
    @Binding var searchText: String
    @Binding var selectedPost: Post?
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search posts...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            .padding()
            
            Divider()
            
            // Post list
            if posts.isEmpty {
                ContentUnavailableView(
                    "No Posts",
                    systemImage: "doc.text",
                    description: Text("Create a new post to get started")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(posts) { post in
                            PostPreviewRow(
                                post: post,
                                isSelected: selectedPost?.id == post.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPost = post
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Timeline")
    }
}
