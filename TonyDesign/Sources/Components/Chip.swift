import SwiftUI

public struct Chip: View {
    public enum Style: Sendable, CaseIterable {
        case neutral
        case selected
        case accent
        case warning

        var background: Color {
            switch self {
            case .neutral: TonyColor.surfaceRaised
            case .selected: TonyColor.ink
            case .accent: TonyColor.accent
            case .warning: TonyColor.warningSoft
            }
        }

        var foreground: Color {
            switch self {
            case .neutral: TonyColor.ink
            case .selected, .accent: TonyColor.onAccent
            case .warning: TonyColor.warning
            }
        }
    }

    private let label: String
    private let style: Style

    public init(_ label: String, style: Style = .neutral) {
        self.label = label
        self.style = style
    }

    public var body: some View {
        Text(label)
            .tonyText(.labelSmall)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(style.foreground)
            .padding(.horizontal, TonySpacing.inset)
            .padding(.vertical, TonySpacing.small)
            .background(style.background, in: .capsule)
    }
}

/// The round icon holder used by task rows and timeline items. Task icons are emoji chosen by the user.
struct IconCircle: View {
    let icon: String
    var isNeglected = false
    @ScaledMetric(relativeTo: .body) private var diameter = TonySize.iconCircle

    var body: some View {
        Text(icon)
            .tonyText(.bodyLarge)
            .frame(width: diameter, height: diameter)
            .background(isNeglected ? TonyColor.warningSoft : TonyColor.surfaceRaised, in: .circle)
            .accessibilityHidden(true)
    }
}
