//
//  LinkCardView.swift
//  jez-blog
//
//  Placeholder editor for link card posts
//

import SwiftUI

struct LinkCardView: View {
    let post: Post
    @State private var urlText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Link Card")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Share a link with preview and commentary")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // URL input
            VStack(alignment: .leading, spacing: 8) {
                Text("URL")
                    .font(.headline)
                
                TextField("https://example.com", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }
            
            // Preview card
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.headline)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "link.circle")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Link preview will appear here")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
            
            // Commentary field
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Commentary")
                    .font(.headline)
                
                TextEditor(text: .constant(""))
                    .font(.body)
                    .fontDesign(.serif)
                    .frame(height: 150)
                    .padding(12)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
