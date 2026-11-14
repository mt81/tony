import SwiftUI
import TonyPresentation

public struct Chip: View {
    private let model: ChipDataModel

    public init(_ model: ChipDataModel) {
        self.model = model
    }

    public var body: some View {
        Text(model.title)
            .tonyText(.labelSmall)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(model.style.foreground)
            .padding(.horizontal, TonySpacing.inset)
            .padding(.vertical, TonySpacing.small)
            .background(model.style.background, in: .capsule)
    }
}

extension ChipDataModel.Style {
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
