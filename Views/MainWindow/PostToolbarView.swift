//
//  PostToolbarView.swift
//  jez-blog
//
//  Toolbar for post editing
//

import SwiftUI
import SwiftData

struct PostToolbarView: View {
    @Environment(\.modelContext) private var modelContext
    let post: Post
    
    var body: some View {
        HStack(spacing: 16) {
            // Publish toggle
            Toggle(isOn: Binding(
                get: { post.publishToWeb },
                set: { newValue in
                    post.publishToWeb = newValue
                    post.modifiedAt = Date()
                    try? modelContext.save()
                }
            )) {
                Label("Publish to Web", systemImage: post.publishToWeb ? "globe" : "eye.slash")
            }
            .toggleStyle(.switch)
            .tint(.accentColor)
            
            Spacer()
            
            // Modified time
            Text("Modified \(relativeTime(from: post.modifiedAt))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Delete button
            Button(role: .destructive) {
                deletePost()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func deletePost() {
        modelContext.delete(post)
        try? modelContext.save()
    }
    
    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
