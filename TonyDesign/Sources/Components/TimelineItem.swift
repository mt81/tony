import SwiftUI

/// One entry of the Today timeline. The five Figma kinds are: now, task with actions, meetings, task, and last task.
public struct TimelineItem: View {
    public struct Action: Identifiable {
        public let label: String
        public let perform: () -> Void

        public var id: String { label }

        public init(_ label: String, perform: @escaping () -> Void) {
            self.label = label
            self.perform = perform
        }
    }

    private enum Kind {
        case now(String)
        case task(icon: String, time: String, title: String, reason: String, actions: [Action], onCheck: () -> Void)
        case meetings(time: String, title: String, detail: String)
    }

    private let kind: Kind
    private let isLast: Bool
    @ScaledMetric(relativeTo: .body) private var railWidth = TonySize.iconCircle

    public static func now(_ text: String) -> TimelineItem {
        TimelineItem(kind: .now(text), isLast: false)
    }

    public static func task(
        icon: String,
        time: String,
        title: String,
        reason: String,
        actions: [Action] = [],
        isLast: Bool = false,
        onCheck: @escaping () -> Void
    ) -> TimelineItem {
        TimelineItem(kind: .task(icon: icon, time: time, title: title, reason: reason, actions: actions, onCheck: onCheck), isLast: isLast)
    }

    public static func meetings(time: String, title: String, detail: String) -> TimelineItem {
        TimelineItem(kind: .meetings(time: time, title: title, detail: detail), isLast: false)
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
        switch kind {
        case .now:
            dot(diameter: TonySize.nowDot, height: TonySize.nowMarkerHeight, colour: TonyColor.accent)
        case .task(let icon, _, _, _, _, _):
            IconCircle(icon: icon)
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
        switch kind {
        case .now(let text):
            Text(text)
                .tonyText(.label)
                .foregroundStyle(TonyColor.accent)
                .padding(.top, TonySpacing.tight)
        case .task(_, let time, let title, let reason, let actions, let onCheck):
            VStack(alignment: .leading, spacing: TonySpacing.snug) {
                HStack(spacing: TonySpacing.medium) {
                    VStack(alignment: .leading, spacing: TonySpacing.textGap) {
                        Text(time).tonyText(.labelSmall).foregroundStyle(TonyColor.muted)
                        Text(title).tonyText(.labelLarge).foregroundStyle(TonyColor.ink)
                        Text(reason).tonyText(.bodySmall).foregroundStyle(TonyColor.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    checkbox(onCheck: onCheck)
                }
                if !actions.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: TonySpacing.small) { actionButtons(actions) }
                        VStack(alignment: .leading, spacing: TonySpacing.small) { actionButtons(actions) }
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

    private func actionButtons(_ actions: [Action]) -> some View {
        ForEach(actions) { action in
            Button(action: action.perform) {
                Chip(action.label)
                    .frame(minHeight: TonySize.touchTarget)
            }
            .buttonStyle(.plain)
        }
    }

    private func checkbox(onCheck: @escaping () -> Void) -> some View {
        Button(action: onCheck) {
            Circle()
                .strokeBorder(TonyColor.muted, lineWidth: TonySize.border)
                .frame(width: TonySize.checkbox, height: TonySize.checkbox)
                .frame(width: TonySize.touchTarget, height: TonySize.touchTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Mark as done", bundle: .design))
    }

    private var isNow: Bool {
        if case .now = kind { true } else { false }
    }
}
