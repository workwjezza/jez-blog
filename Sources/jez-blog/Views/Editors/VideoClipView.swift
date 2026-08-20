//
//  VideoClipView.swift
//  jez-blog
//
//  Placeholder editor for video clip posts
//

import SwiftUI

struct VideoClipView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Video Clip")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Single video with optional caption")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Video drop zone
            VStack(alignment: .leading, spacing: 8) {
                Text("Video")
                    .font(.headline)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 400)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "video")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Drop Video Here")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
            
            // Caption field
            VStack(alignment: .leading, spacing: 8) {
                Text("Caption")
                    .font(.headline)
                
                TextEditor(text: .constant(""))
                    .font(.body)
                    .fontDesign(.serif)
                    .frame(height: 100)
                    .padding(12)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
