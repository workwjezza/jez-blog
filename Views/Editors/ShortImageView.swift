//
//  ShortImageView.swift
//  jez-blog
//
//  Placeholder editor for short text + image posts
//

import SwiftUI

struct ShortImageView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Short + Image")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("One text block paired with an image")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Text area
            VStack(alignment: .leading, spacing: 8) {
                Text("Text")
                    .font(.headline)
                
                TextEditor(text: .constant(""))
                    .font(.body)
                    .fontDesign(.serif)
                    .frame(height: 150)
                    .padding(12)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
            }
            
            // Image drop zone
            VStack(alignment: .leading, spacing: 8) {
                Text("Image")
                    .font(.headline)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 300)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Drop Image Here")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
