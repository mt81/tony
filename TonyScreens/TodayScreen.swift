import SwiftUI
import TonyPresentation
import TonyUIKit
import TonyUIModels

/// The Today tab, drawn from its data model.
public struct TodayScreen: View {
    private let model: TodayScreenDataModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(_ model: TodayScreenDataModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TonySpacing.section) {
                header
                if let consistency = model.consistency {
                    ConsistencyGraph(consistency)
                }
                briefing
                timeline
                if !model.tiles.isEmpty {
                    tiles
                }
            }
            .padding(.horizontal, TonySpacing.page)
            .padding(.top, TonySpacing.small)
            .padding(.bottom, TonySpacing.section)
        }
        .background { PageBackground() }
        .onAppear(perform: model.onAppear)
        .sheet(item: Binding(get: { model.editor }, set: { if $0 == nil { model.dismissEditor() } })) { editor in
            TaskEditorScreen(editor)
        }
        .alert(model.alert)
    }

    private var header: some View {
        VStack(spacing: TonySpacing.large) {
            TonyImage()
                .frame(width: TonySize.tonyHeader, height: TonySize.tonyHeader)
            VStack(spacing: TonySpacing.tight) {
                Text(model.date)
                    .tonyText(.bodySmall)
                    .foregroundStyle(TonyColor.muted)
                Text(model.headline)
                    .tonyText(.display)
                    .foregroundStyle(TonyColor.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("todayHeadline")
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, TonySpacing.small)
    }

    private var briefing: some View {
        VStack(alignment: .leading, spacing: TonySpacing.inset) {
            HStack(spacing: TonySpacing.small) {
                TonyImage()
                    .frame(width: TonySize.tonyByline, height: TonySize.tonyByline)
                Text(model.briefing.author).tonyText(.labelStrong).foregroundStyle(TonyColor.ink)
                Text(model.briefing.time).tonyText(.caption).foregroundStyle(TonyColor.muted)
            }
            .accessibilityElement(children: .combine)
            Text(model.briefing.text)
                .tonyText(.bodyLarge)
                .foregroundStyle(TonyColor.ink)
                .accessibilityIdentifier("todayBriefing")
            if let question = model.briefing.question {
                Text(question)
                    .tonyText(.body)
                    .foregroundStyle(TonyColor.muted)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TonySpacing.small) { answers }
                    VStack(alignment: .leading, spacing: TonySpacing.small) { answers }
                }
            }
        }
    }

    private var answers: some View {
        ForEach(model.briefing.answers.indices, id: \.self) { index in
            let answer = model.briefing.answers[index]
            Button(action: answer.action) {
                Chip(ChipDataModel(title: answer.title))
                    .frame(minHeight: TonySize.touchTarget)
            }
            .buttonStyle(.plain)
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: TonySpacing.large) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: TonySpacing.small) {
                    sectionTitle(model.timelineTitle)
                    Spacer()
                    timelineHint
                }
                VStack(alignment: .leading, spacing: TonySpacing.xSmall) {
                    sectionTitle(model.timelineTitle)
                    timelineHint
                }
            }
            VStack(spacing: 0) {
                ForEach(model.timeline) { entry in
                    TimelineItem(entry.item)
                }
            }
            DashedButton(model.addTask)
        }
    }

    private var timelineHint: some View {
        Text(model.timelineHint)
            .tonyText(.caption)
            .foregroundStyle(TonyColor.muted)
    }

    private var tiles: some View {
        VStack(alignment: .leading, spacing: TonySpacing.inset) {
            sectionTitle(model.tilesTitle)
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: TonySpacing.medium, alignment: .top),
                    count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                ),
                spacing: TonySpacing.medium
            ) {
                ForEach(model.tiles) { tile in
                    Tile(tile.tile)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .tonyText(.heading)
            .foregroundStyle(TonyColor.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview("Today") {
    TodayScreen(PreviewSamples.today())
        .tonyPreview(padding: 0)
}

#Preview("Today, nothing planned") {
    TodayScreen(PreviewSamples.emptyToday)
        .tonyPreview(padding: 0)
}

#Preview("Today, largest text") {
    TodayScreen(PreviewSamples.today())
        .tonyPreview(padding: 0)
        .dynamicTypeSize(.accessibility5)
}

#Preview("Today, answer not saved") {
    TodayScreen(PreviewSamples.today(alert: AlertDataModel(title: "Your answer could not be saved", dismiss: ButtonDataModel(title: "OK") {})))
        .tonyPreview(padding: 0)
}
#endif
