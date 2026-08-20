//
//  ThreadComposerView.swift
//  jez-blog
//
//  Fully functional thread composer with block management
//

import SwiftUI
import SwiftData

struct ThreadComposerView: View {
    @Environment(\.modelContext) private var modelContext
    let post: Post
    
    @State private var blocks: [ContentBlock] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Thread Composer")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    addBlock()
                } label: {
                    Label("Add Block", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }
            .padding(.bottom, 8)
            
            // Blocks
            if blocks.isEmpty {
                ContentUnavailableView(
                    "No Blocks",
                    systemImage: "text.alignleft",
                    description: Text("Add a block to start writing")
                )
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                VStack(spacing: 20) {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        VStack(spacing: 12) {
                            BlockCardView(
                                block: block,
                                blockNumber: index + 1,
                                canMoveUp: index > 0,
                                canMoveDown: index < blocks.count - 1,
                                onMoveUp: { moveBlock(block, direction: .up) },
                                onMoveDown: { moveBlock(block, direction: .down) },
                                onDelete: { deleteBlock(block) },
                                onContentChange: { newContent in
                                    updateBlockContent(block, content: newContent)
                                }
                            )
                            
                            // Insert button between blocks
                            if index < blocks.count - 1 {
                                Button {
                                    insertBlockAfter(block)
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.title3)
                                        .foregroundStyle(.accentColor)
                                }
                                .buttonStyle(.plain)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadBlocks()
        }
    }
    
    private func loadBlocks() {
        if let postBlocks = post.blocks {
            blocks = postBlocks.sorted { $0.orderIndex < $1.orderIndex }
        }
    }
    
    private func addBlock() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let newBlock = ContentBlock(
                orderIndex: blocks.count,
                content: "",
                blockType: .text,
                characterLimit: 280
            )
            newBlock.post = post
            modelContext.insert(newBlock)
            blocks.append(newBlock)
            post.modifiedAt = Date()
            try? modelContext.save()
        }
    }
    
    private func insertBlockAfter(_ block: ContentBlock) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let insertIndex = block.orderIndex + 1
            
            // Shift all blocks after this one
            for b in blocks where b.orderIndex >= insertIndex {
                b.orderIndex += 1
            }
            
            let newBlock = ContentBlock(
                orderIndex: insertIndex,
                content: "",
                blockType: .text,
                characterLimit: 280
            )
            newBlock.post = post
            modelContext.insert(newBlock)
            
            loadBlocks()
            post.modifiedAt = Date()
            try? modelContext.save()
        }
    }
    
    private func deleteBlock(_ block: ContentBlock) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let deletedIndex = block.orderIndex
            
            modelContext.delete(block)
            
            // Reindex remaining blocks
            for b in blocks where b.orderIndex > deletedIndex {
                b.orderIndex -= 1
            }
            
            loadBlocks()
            post.modifiedAt = Date()
            try? modelContext.save()
        }
    }
    
    private func moveBlock(_ block: ContentBlock, direction: MoveDirection) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let currentIndex = block.orderIndex
            let targetIndex = direction == .up ? currentIndex - 1 : currentIndex + 1
            
            guard targetIndex >= 0 && targetIndex < blocks.count else { return }
            
            // Find the block to swap with
            if let targetBlock = blocks.first(where: { $0.orderIndex == targetIndex }) {
                // Swap order indices
                block.orderIndex = targetIndex
                targetBlock.orderIndex = currentIndex
                
                loadBlocks()
                post.modifiedAt = Date()
                try? modelContext.save()
            }
        }
    }
    
    private func updateBlockContent(_ block: ContentBlock, content: String) {
        block.content = content
        post.modifiedAt = Date()
        try? modelContext.save()
    }
}

enum MoveDirection {
    case up, down
}
