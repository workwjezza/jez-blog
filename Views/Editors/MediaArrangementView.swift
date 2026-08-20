//
//  MediaArrangementView.swift
//  jez-blog
//
//  Placeholder editor for media arrangement posts
//

import SwiftUI

struct MediaArrangementView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Media Arrangement")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Arrange 1-4 images in a grid layout")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // 2x2 grid placeholder
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.05))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("Drop Image")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
