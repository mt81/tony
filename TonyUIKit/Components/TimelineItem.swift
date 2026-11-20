import SwiftUI
import TonyUIModels

/// One entry of the Today timeline: what is done, now, a task, or meetings. A rail on the left joins the entries.
/// A task's ring marks it done; its other actions are in its context menu.
public struct TimelineItem: View {
    private let model: TimelineItemDataModel
    @ScaledMetric(relativeTo: .body) private var railWidth = TonySize.iconCircle
    @ScaledMetric(relativeTo: .caption) private var markerOffset = TonySize.markerOffset

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
            if hasLineAbove {
                line(TonyColor.ring)
                    .frame(height: markerOffset)
            }
            marker
            if !isLast {
                line(isDone ? TonyColor.ink : TonyColor.ring)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: railWidth)
    }

    private func line(_ colour: Color) -> some View {
        Rectangle()
            .fill(colour)
            .frame(width: TonySize.rail)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var marker: some View {
        switch model {
        case .done:
            Circle()
                .fill(TonyColor.ink)
                .frame(width: TonySize.marker, height: TonySize.marker)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: TonySize.markerCheck, weight: .bold))
                        .foregroundStyle(TonyColor.canvas)
                }
                .padding(.top, markerOffset)
                .accessibilityHidden(true)
        case .now:
            ring(TonyColor.accent)
                .frame(height: TonySize.nowMarkerHeight)
                .accessibilityHidden(true)
        case .task(let item, _):
            checkButton(item)
                .frame(height: item.now == nil ? nil : TonySize.nowMarkerHeight)
        case .meetings:
            Circle()
                .fill(TonyColor.muted)
                .frame(width: TonySize.meetingsDot, height: TonySize.meetingsDot)
                .frame(height: TonySize.meetingsMarkerHeight)
                .accessibilityHidden(true)
        }
    }

    private func ring(_ colour: Color) -> some View {
        Circle()
            .strokeBorder(colour, lineWidth: TonySize.border)
            .frame(width: TonySize.marker, height: TonySize.marker)
    }

    private func checkButton(_ item: TimelineItemDataModel.TaskItem) -> some View {
        Button {
            item.check.action.execute()
        } label: {
            ring(item.now != nil ? TonyColor.accent : item.isNeglected ? TonyColor.warning : TonyColor.ring)
                .contentShape(.rect.inset(by: (TonySize.marker - TonySize.touchTarget) / 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.check.title)
        .accessibilityIdentifier(ifPresent: item.check.accessibilityIdentifier)
    }

    @ViewBuilder private var content: some View {
        switch model {
        case .done(let text):
            Text(text)
                .tonyText(.bodySmall)
                .foregroundStyle(TonyColor.ink)
                .padding(.top, markerOffset)
        case .now(let text):
            Text(text)
                .tonyText(.label)
                .foregroundStyle(TonyColor.accent)
                .padding(.top, TonySpacing.tight)
        case .task(let item, _):
            VStack(alignment: .leading, spacing: TonySpacing.textGap) {
                if let now = item.now {
                    Text(now).tonyText(.label).foregroundStyle(TonyColor.accent)
                } else {
                    Text(item.time).tonyText(.labelSmall).foregroundStyle(TonyColor.ink)
                }
                Text(verbatim: "\(item.icon) \(item.title)").tonyText(.labelLarge).foregroundStyle(TonyColor.ink)
                Text(item.reason).tonyText(.bodySmall).foregroundStyle(item.isNeglected ? TonyColor.warning : TonyColor.ink)
            }
            .padding(.top, item.now == nil ? 0 : TonySpacing.tight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(ifPresent: item.accessibilityIdentifier)
            .contextMenu {
                ForEach(item.actions.indices, id: \.self) { index in
                    let action = item.actions[index]
                    Button(action.title) { action.action.execute() }
                        .disabled(!action.isEnabled)
                        .accessibilityIdentifier(ifPresent: action.accessibilityIdentifier)
                }
            }
        case .meetings(let time, let title, let detail):
            VStack(alignment: .leading, spacing: TonySpacing.hairline) {
                Text(time).tonyText(.labelSmall)
                Text(title).tonyText(.label)
                Text(detail).tonyText(.caption)
            }
            .foregroundStyle(TonyColor.ink)
            .opacity(TonyOpacity.meetings)
            .accessibilityElement(children: .combine)
        }
    }

    private var isDone: Bool {
        if case .done = model { true } else { false }
    }

    /// Tasks start with a stretch of rail, so their ring lines up with their name; the task to do now does not.
    private var hasLineAbove: Bool {
        if case .task(let item, _) = model { item.now == nil } else { false }
    }

    private var isLast: Bool {
        if case .task(_, let isLast) = model { isLast } else { false }
    }
}

#if DEBUG
#Preview("Timeline items") {
    let check = ButtonDataModel(title: "Mark as done", action: Action(id: "preview") { _ in })
    let items: [TimelineItemDataModel] = [
        .done(text: "Good job, today you already did Supplements and Grocery."),
        .task(
            .init(
                icon: "🧺",
                time: "8:30",
                title: "Start a load of laundry",
                reason: "Before your 10:00 meetings. It runs on its own.",
                actions: ["Later", "Not today"].map { ButtonDataModel(title: $0, action: Action(id: "preview") { _ in }) },
                check: check,
                now: "8:30 · a good moment to start"
            ),
            isLast: false
        ),
        .meetings(time: "10:00", title: "3 meetings, back to back", detail: "Daily scrum · Weekly sync · 1 more · until 11:00"),
        .task(.init(icon: "🪴", time: "3:30", title: "Water the plants", reason: "5 days since last time", check: check, isNeglected: true), isLast: false),
        .task(.init(icon: "🏋️", time: "18:00", title: "Gym", reason: "Kept for the evening.", check: check), isLast: true),
    ]
    return ScrollView {
        VStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                TimelineItem(items[index])
            }
        }
    }
    .tonyPreview()
}

#Preview("Timeline, nothing soon") {
    let check = ButtonDataModel(title: "Mark as done", action: Action(id: "preview") { _ in })
    VStack(spacing: 0) {
        TimelineItem(.now(text: "Now"))
        TimelineItem(.task(.init(icon: "🏋️", time: "18:00", title: "Gym", reason: "Kept for the evening.", check: check), isLast: true))
    }
    .tonyPreview()
}
#endif
