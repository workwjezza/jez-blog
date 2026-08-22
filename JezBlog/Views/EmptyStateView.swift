//
//  EmptyStateView.swift
//  jez-blog
//

import SwiftUI

/// A calm, centered placeholder used by the timeline and detail panes.
struct EmptyStateView: View {
    let symbolName: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    /// Extra controls shown beneath the message — a row of new post buttons,
    /// for instance.
    var accessory: AnyView? = nil


    var body: some View {
        VStack(spacing: Theme.componentSpacing) {
            Image(systemName: symbolName)
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Theme.accent.opacity(0.7))

            Text(title)
                .font(.title3.weight(.medium))
                .fontDesign(.serif)

            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .padding(.top, 4)
            }

            if let accessory {
                accessory
                    .frame(maxWidth: 460)
                    .padding(.top, 4)
            }
        }

        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        symbolName: "leaf",
        title: "No Posts",
        message: "Your media garden is empty. Plant something.",
        actionTitle: "New Post",
        action: {}
    )
    .frame(width: 500, height: 400)
}
