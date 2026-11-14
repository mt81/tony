import SwiftUI
import TonyPresentation
import TonyUIKit

/// Every component with the sample content of the Figma "Components" frame, to compare the two side by side.
/// Debug builds only: its text is sample data, not translated.
public struct ComponentGallery: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TonySpacing.section) {
                Text(verbatim: "Components")
                    .tonyText(.display)
                    .foregroundStyle(TonyColor.ink)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TonySpacing.medium) { chips }
                    VStack(alignment: .leading, spacing: TonySpacing.medium) { chips }
                }

                HStack(spacing: TonySpacing.timeline) {
                    TonyIcon.today
                    TonyIcon.tasks
                    TonyIcon.you
                    TonyImage().frame(height: TonySize.touchTarget)
                }
                .foregroundStyle(TonyColor.ink)

                VStack(spacing: 0) {
                    ForEach(timeline.indices, id: \.self) { index in
                        TimelineItem(timeline[index])
                    }
                }

                TaskRow(Self.row(icon: "🧺", title: "Laundry", subtitle: "Every week · wash, dry, fold", status: ChipDataModel(title: "Today")))
                TaskRow(
                    Self.row(
                        icon: "🥀",
                        title: "Water the plants",
                        subtitle: "Every 5 days after last time",
                        status: ChipDataModel(title: "Due", style: .warning),
                        isNeglected: true
                    )
                )

                HStack(alignment: .top, spacing: TonySpacing.medium) {
                    Tile(TileDataModel(icon: "🛏️🪰", title: "Bed sheets", detail: "16 days. The flies moved in.", isNeglected: true))
                    Stat(StatDataModel(value: "12", label: "tasks done"))
                }

                AreaRow(AreaRowDataModel(name: "Home", progress: 0.6, status: "Good"))

                VStack(alignment: .leading, spacing: TonySpacing.small) {
                    ForEach(TonyTextStyle.allCases, id: \.self) { style in
                        Text(verbatim: String(describing: style)).tonyText(style)
                    }
                }
                .foregroundStyle(TonyColor.ink)
            }
            .padding(TonySpacing.page)
        }
        .background(TonyColor.canvas)
    }

    private var chips: some View {
        ForEach(ChipDataModel.Style.allCases, id: \.self) { style in
            Chip(ChipDataModel(title: "Label", style: style))
        }
    }

    private var timeline: [TimelineItemDataModel] {
        let check = ButtonDataModel(title: "Mark as done") {}
        return [
            .now(text: "Now · a good moment to start the laundry"),
            .task(
                .init(
                    icon: "🧺",
                    time: "8:30",
                    title: "Start a load of laundry",
                    reason: "Before your 10:00 meetings. It runs on its own.",
                    actions: ["Move to noon", "Swap", "Not today"].map { ButtonDataModel(title: $0) {} },
                    check: check
                ),
                isLast: false
            ),
            .meetings(time: "10:00", title: "3 meetings, back to back", detail: "Daily scrum · Weekly sync · 1 more · until 11:00"),
            .task(.init(icon: "🧺", time: "11:15", title: "Move laundry to the dryer", reason: "Right after your last morning meeting", check: check), isLast: false),
            .task(.init(icon: "🏋️", time: "Evening", title: "Gym", reason: "2 of 4 this week, or tomorrow. Your call.", check: check), isLast: true),
        ]
    }

    private static func row(icon: String, title: String, subtitle: String, status: ChipDataModel, isNeglected: Bool = false) -> TaskRowDataModel {
        TaskRowDataModel(
            id: UUID(),
            icon: icon,
            title: title,
            subtitle: subtitle,
            status: status,
            isNeglected: isNeglected,
            accessibilityIdentifier: title,
            open: {},
            delete: ButtonDataModel(title: "Delete", role: .destructive) {}
        )
    }
}

#Preview {
    ComponentGallery()
}
