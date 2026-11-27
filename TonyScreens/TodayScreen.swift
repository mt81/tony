import SwiftUI
import TonyPresentation
import TonyUIKit
import TonyUIModels

/// The Today tab, drawn from its view model. Each part reads only its own values, so it redraws on its own.
public struct TodayScreen: View {
    private let viewModel: TodayViewModel

    public init(_ viewModel: TodayViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TonySpacing.section) {
                TodayHeader(viewModel: viewModel)
                TodayBriefing(viewModel: viewModel)
                TodayCalendar(viewModel: viewModel)
                TodayTimeline(viewModel: viewModel)
                TodayTiles(viewModel: viewModel)
            }
            .padding(.horizontal, TonySpacing.page)
            .padding(.bottom, TonySpacing.section)
        }
        .background { PageBackground() }
        .task { await viewModel.load() }
        .sheet(item: Binding(get: { viewModel.editor }, set: { if $0 == nil { viewModel.dismissEditor.execute() } })) { editor in
            TaskEditorScreen(editor)
        }
        .alert(viewModel.alert)
    }
}

private struct TodayHeader: View {
    let viewModel: TodayViewModel

    var body: some View {
        VStack(spacing: TonySpacing.large) {
            TonyImage()
                .frame(width: TonySize.tonyHeader, height: TonySize.tonyHeader)
            VStack(spacing: TonySpacing.tight) {
                Text(viewModel.date)
                    .tonyText(.bodySmall)
                Text(viewModel.headline.accented())
                    .tonyText(.display)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("todayHeadline")
            }
            .foregroundStyle(TonyColor.ink)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TodayBriefing: View {
    let viewModel: TodayViewModel

    var body: some View {
        Text(viewModel.briefing)
            .tonyText(.briefing)
            .foregroundStyle(TonyColor.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(TonySpacing.page)
            .background(TonyColor.glass, in: .rect(cornerRadius: TonyRadius.panel))
            .accessibilityIdentifier("todayBriefing")
    }
}

private struct TodayCalendar: View {
    let viewModel: TodayViewModel

    var body: some View {
        if let calendar = viewModel.calendar {
            CalendarCard(calendar)
        }
    }
}

private struct TodayTimeline: View {
    let viewModel: TodayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: TonySpacing.large) {
            TodaySectionTitle(title: viewModel.timelineTitle)
            VStack(spacing: 0) {
                ForEach(viewModel.timeline) { entry in
                    TimelineItem(entry.item)
                }
            }
        }
    }
}

private struct TodayTiles: View {
    let viewModel: TodayViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let tiles = viewModel.tiles
        if !tiles.isEmpty {
            VStack(alignment: .leading, spacing: TonySpacing.inset) {
                TodaySectionTitle(title: viewModel.tilesTitle)
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: TonySpacing.medium, alignment: .top),
                        count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                    ),
                    spacing: TonySpacing.inset
                ) {
                    ForEach(tiles) { tile in
                        Tile(tile.tile)
                    }
                }
            }
        }
    }
}

private struct TodaySectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .tonyText(.heading)
            .foregroundStyle(TonyColor.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview("Today") {
    TodayScreen(.preview())
        .tonyPreview(padding: 0)
}

#Preview("Today, calendar not connected") {
    TodayScreen(.preview(canAllowCalendar: true))
        .tonyPreview(padding: 0)
}

#Preview("Today, nothing planned") {
    TodayScreen(.preview(hasTasks: false, canAllowCalendar: true))
        .tonyPreview(padding: 0)
}

#Preview("Today, largest text") {
    TodayScreen(.preview())
        .tonyPreview(padding: 0)
        .dynamicTypeSize(.accessibility5)
}

#Preview("Today, answer not saved") {
    TodayScreen(.preview(failure: true))
        .tonyPreview(padding: 0)
}
#endif
