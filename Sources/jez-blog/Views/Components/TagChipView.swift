//
//  TagChipView.swift
//  jez-blog
//
//  Tag chip component
//

import SwiftUI

struct TagChipView: View {
    let tag: String
    
    var body: some View {
        Text("#\(tag)")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.2))
            .foregroundStyle(.accentColor)
            .cornerRadius(6)
    }
}
