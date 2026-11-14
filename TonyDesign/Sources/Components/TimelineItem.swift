import SwiftUI
import TonyPresentation
import TonyUIKit

/// One entry of the Today timeline. The five Figma kinds are: now, task with actions, meetings, task, and last task.
public struct TimelineItem: View {
    private let model: TimelineItemDataModel
    @ScaledMetric(relativeTo: .body) private var railWidth = TonySize.iconCircle

    public init(_ model: TimelineItemDataModel) {
        self.model = model
    }

    public var body: some View {
        HStack(alignment: .top, spacing: TonySpacing.medium) {
            rail
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, isLast ? 0 : TonySpacing.timeline)
        }
    }

    private var rail: some View {
        VStack(spacing: 0) {
            marker
            if !isLast {
                Rectangle()
                    .fill(isNow ? TonyColor.accent : TonyColor.line)
                    .frame(width: TonySize.rail)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: railWidth)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var marker: some View {
        switch model {
        case .now:
            dot(diameter: TonySize.nowDot, height: TonySize.nowMarkerHeight, colour: TonyColor.accent)
        case .task(let item, _):
            IconCircle(icon: item.icon)
        case .meetings:
            dot(diameter: TonySize.meetingsDot, height: TonySize.meetingsMarkerHeight, colour: TonyColor.muted)
        }
    }

    private func dot(diameter: CGFloat, height: CGFloat, colour: Color) -> some View {
        Circle()
            .fill(colour)
            .frame(width: diameter, height: diameter)
            .frame(height: height)
    }

    @ViewBuilder private var content: some View {
        switch model {
        case .now(let text):
            Text(text)
                .tonyText(.label)
                .foregroundStyle(TonyColor.accent)
                .padding(.top, TonySpacing.tight)
        case .task(let item, _):
            VStack(alignment: .leading, spacing: TonySpacing.snug) {
                HStack(spacing: TonySpacing.medium) {
                    VStack(alignment: .leading, spacing: TonySpacing.textGap) {
                        Text(item.time).tonyText(.labelSmall).foregroundStyle(TonyColor.muted)
                        Text(item.title).tonyText(.labelLarge).foregroundStyle(TonyColor.ink)
                        Text(item.reason).tonyText(.bodySmall).foregroundStyle(TonyColor.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    checkbox(item.check)
                }
                if !item.actions.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: TonySpacing.small) { actionButtons(item.actions) }
                        VStack(alignment: .leading, spacing: TonySpacing.small) { actionButtons(item.actions) }
                    }
                }
            }
        case .meetings(let time, let title, let detail):
            VStack(alignment: .leading, spacing: TonySpacing.hairline) {
                Text(time).tonyText(.labelSmall).foregroundStyle(TonyColor.muted)
                Text(title).tonyText(.label).foregroundStyle(TonyColor.ink)
                Text(detail).tonyText(.caption).foregroundStyle(TonyColor.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TonySpacing.inset)
            .padding(.vertical, TonySpacing.cardVertical)
            .background(TonyColor.surface, in: .rect(cornerRadius: TonyRadius.card))
            .accessibilityElement(children: .combine)
        }
    }

    private func actionButtons(_ actions: [ButtonDataModel]) -> some View {
        ForEach(actions.indices, id: \.self) { index in
            let action = actions[index]
            Button(action: action.action) {
                Chip(ChipDataModel(title: action.title))
                    .frame(minHeight: TonySize.touchTarget)
            }
            .buttonStyle(.plain)
            .disabled(!action.isEnabled)
        }
    }

    private func checkbox(_ check: ButtonDataModel) -> some View {
        Button(action: check.action) {
            Circle()
                .strokeBorder(TonyColor.muted, lineWidth: TonySize.border)
                .frame(width: TonySize.checkbox, height: TonySize.checkbox)
                .frame(width: TonySize.touchTarget, height: TonySize.touchTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(check.title)
    }

    private var isNow: Bool {
        if case .now = model { true } else { false }
    }

    private var isLast: Bool {
        if case .task(_, let isLast) = model { isLast } else { false }
    }
}
