//
//  BlockCardView.swift
//  jez-blog
//
//  Individual block card with editing controls
//

import SwiftUI

struct BlockCardView: View {
    let block: ContentBlock
    let blockNumber: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let onContentChange: (String) -> Void
    
    @State private var isHovered: Bool = false
    @FocusState private var isFocused: Bool
    
    var characterCount: Int {
        block.content.count
    }
    
    var isOverLimit: Bool {
        if let limit = block.characterLimit {
            return characterCount > limit
        }
        return false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with block number and controls
            HStack {
                // Block number badge
                Text("#\(blockNumber)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .cornerRadius(6)
                
                Spacer()
                
                // Character counter
                HStack(spacing: 4) {
                    Text("\(characterCount)")
                        .fontWeight(.semibold)
                        .foregroundStyle(isOverLimit ? .red : .primary)
                    
                    if let limit = block.characterLimit {
                        Text("/ \(limit)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .monospacedDigit()
                
                // Hover controls
                if isHovered {
                    HStack(spacing: 8) {
                        if canMoveUp {
                            Button {
                                onMoveUp()
                            } label: {
                                Image(systemName: "arrow.up")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        
                        if canMoveDown {
                            Button {
                                onMoveDown()
                            } label: {
                                Image(systemName: "arrow.down")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            
            // Text editor
            TextEditor(text: Binding(
                get: { block.content },
                set: { onContentChange($0) }
            ))
            .font(.body)
            .fontDesign(.serif)
            .frame(minHeight: 100)
            .scrollContentBackground(.hidden)
            .focused($isFocused)
        }
        .padding(16)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(
            color: Color.black.opacity(isHovered ? 0.15 : 0.08),
            radius: isHovered ? 12 : 6,
            x: 0,
            y: isHovered ? 6 : 3
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
