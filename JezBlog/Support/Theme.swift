//
//  Theme.swift
//  jez-blog
//
//  Visual language for the media garden: warm, calm, tactile.
//

import SwiftUI

// MARK: - Colors

extension Color {
    /// Creates a color from a hex string such as "FF6B35" or "#FF6B35".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: Double
        switch cleaned.count {
        case 3: // RGB (12-bit)
            r = Double((value >> 8) & 0xF) / 15
            g = Double((value >> 4) & 0xF) / 15
            b = Double(value & 0xF) / 15
            a = 1
        case 6: // RGB (24-bit)
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        case 8: // ARGB (32-bit)
            a = Double((value >> 24) & 0xFF) / 255
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1; a = 1
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Design tokens shared by every view.
enum Theme {

    // MARK: Palette

    /// macOS system blue — #007AFF in light, #0A84FF in dark.
    /// Matches `Assets.xcassets/AccentColor` and the platform's own controls.
    static let accent = Color(nsColor: .systemBlue)

    /// Soft fill used by cards and drop zones.
    static let cardFill = Color.primary.opacity(0.05)

    /// Slightly stronger fill for hovered/active surfaces.
    static let cardFillHover = Color.primary.opacity(0.08)

    /// Hairline separators.
    static let hairline = Color.primary.opacity(0.08)

    // MARK: Metrics

    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 20
    static let componentSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 12
    static let minBlockHeight: CGFloat = 100

    // MARK: Motion

    /// The signature spring used for every structural change.
    /// Softer, more buttery animation with lower damping for gentle settling.
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.75)

    /// Smooth hover transitions.
    static let hover = Animation.easeInOut(duration: 0.25)

    /// Cards scale + fade in and out.
    static let cardTransition = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.96).combined(with: .opacity),
        removal: .scale(scale: 0.96).combined(with: .opacity)
    )

    /// Extra smooth spring for selections and highlights.
    static let selection = Animation.spring(response: 0.35, dampingFraction: 0.85)

    /// Gentle pop animation for window appearances.
    static let windowAppear = Animation.spring(response: 0.4, dampingFraction: 0.7)
}

// MARK: - Reusable styling

/// A soft, rounded surface used for cards and drop zones.
struct CardSurface: ViewModifier {
    var isHighlighted: Bool = false
    var isHovering: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(isHovering ? Theme.cardFillHover : Theme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        isHighlighted ? Theme.accent : Theme.hairline,
                        lineWidth: isHighlighted ? 2 : 1
                    )
            )
            .shadow(
                color: .black.opacity(isHovering ? 0.12 : 0.05),
                radius: isHovering ? 10 : 4,
                x: 0,
                y: isHovering ? 4 : 2
            )
    }
}

extension View {
    /// Applies the standard card surface treatment.
    func cardSurface(isHighlighted: Bool = false, isHovering: Bool = false) -> some View {
        modifier(CardSurface(isHighlighted: isHighlighted, isHovering: isHovering))
    }
}

/// A dashed placeholder used by the media / video / link editors.
struct DropZone: View {
    let symbolName: String
    let title: String
    var subtitle: String? = nil
    var minHeight: CGFloat = 140

    /// True while a drag is hovering over this zone.
    var isTargeted: Bool = false

    @State private var isHovering = false

    private var isActive: Bool { isHovering || isTargeted }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(isActive ? Theme.accent : Color.secondary)
                .scaleEffect(isTargeted ? 1.15 : 1)

            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: minHeight)
        .padding(Theme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(isTargeted ? Theme.accent.opacity(0.08) : Theme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(
                    isActive ? Theme.accent.opacity(0.7) : Theme.hairline,
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [6, 4])
                )
        )
        .animation(Theme.hover, value: isTargeted)
        .onHover { hovering in
            withAnimation(Theme.hover) { isHovering = hovering }
        }
    }
}

/// Section heading used across the editors.
struct EditorHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .fontDesign(.serif)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
    }
}

extension EditorHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - Formatting

extension Date {
    /// "Just now", "12 min ago", "Yesterday" …
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        if Date().timeIntervalSince(self) < 60 { return "just now" }
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var shortDescription: String {
        formatted(date: .abbreviated, time: .shortened)
    }

    /// "12 August 2026" — the byline used on exported pages.
    var longDescription: String {
        formatted(.dateTime.day().month(.wide).year())
    }

    /// ISO-8601, for `<time datetime="…">` and JSON Feed.
    var isoDescription: String {
        ISO8601DateFormatter().string(from: self)
    }
}

// MARK: - Bindings

extension Binding where Value == String? {
    /// Bridges an optional string to a text field, treating "" as nil.
    var orEmpty: Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                wrappedValue = trimmed.isEmpty ? nil : newValue
            }
        )
    }
}

// MARK: - App events

extension Notification.Name {
    /// Posted by the menu bar / ⌘N so the active window can create a post.
    static let newPostRequested = Notification.Name("jezblog.newPostRequested")

    /// Posted by File ▸ Export Site… (⇧⌘E).
    static let exportSiteRequested = Notification.Name("jezblog.exportSiteRequested")
}
