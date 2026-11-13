import SwiftUI

/// Every component with the sample content of the Figma "Components" frame, to compare the two side by side.
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
                    TimelineItem.now("Now · a good moment to start the laundry")
                    TimelineItem.task(
                        icon: "🧺",
                        time: "8:30",
                        title: "Start a load of laundry",
                        reason: "Before your 10:00 meetings. It runs on its own.",
                        actions: [
                            TimelineItem.Action("Move to noon") {},
                            TimelineItem.Action("Swap") {},
                            TimelineItem.Action("Not today") {},
                        ],
                        onCheck: {}
                    )
                    TimelineItem.meetings(
                        time: "10:00",
                        title: "3 meetings, back to back",
                        detail: "Daily scrum · Weekly sync · 1 more · until 11:00"
                    )
                    TimelineItem.task(
                        icon: "🧺",
                        time: "11:15",
                        title: "Move laundry to the dryer",
                        reason: "Right after your last morning meeting",
                        onCheck: {}
                    )
                    TimelineItem.task(
                        icon: "🏋️",
                        time: "Evening",
                        title: "Gym",
                        reason: "2 of 4 this week, or tomorrow. Your call.",
                        isLast: true,
                        onCheck: {}
                    )
                }

                TaskRow(icon: "🧺", title: "Laundry", subtitle: "Every week · wash, dry, fold", status: "Today")
                TaskRow(icon: "🥀", title: "Water the plants", subtitle: "Every 5 days after last time", status: "Due", isNeglected: true)

                HStack(alignment: .top, spacing: TonySpacing.medium) {
                    Tile(icon: "🛏️🪰", title: "Bed sheets", detail: "16 days. The flies moved in.", isNeglected: true)
                    Stat(value: "12", label: "tasks done")
                }

                AreaRow(name: "Home", progress: 0.6, status: "Good")

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
}

extension ComponentGallery {
    private var chips: some View {
        ForEach(Chip.Style.allCases, id: \.self) { style in
            Chip("Label", style: style)
        }
    }
}

#Preview {
    ComponentGallery()
}
