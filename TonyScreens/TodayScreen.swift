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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TonySpacing.section) {
                    header
                    briefing
                    timeline
                    if !model.tiles.isEmpty {
                        tiles
                    }
                }
                .padding(.horizontal, TonySpacing.page)
                .padding(.bottom, TonySpacing.section)
            }
            .background { PageBackground() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.addTask.action.execute()
                    } label: {
                        Label(model.addTask.title, systemImage: model.addTask.systemImage ?? "plus")
                    }
                    .accessibilityIdentifier(ifPresent: model.addTask.accessibilityIdentifier)
                }
            }
        }
        .onAppear { model.onAppear.execute() }
        .sheet(item: Binding(get: { model.editor }, set: { if $0 == nil { model.dismissEditor.execute() } })) { editor in
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
                Text(model.headline)
                    .tonyText(.display)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("todayHeadline")
            }
            .foregroundStyle(TonyColor.ink)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var briefing: some View {
        Text(model.briefing)
            .tonyText(.briefing)
            .foregroundStyle(TonyColor.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("todayBriefing")
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: TonySpacing.large) {
            sectionTitle(model.timelineTitle)
            VStack(spacing: 0) {
                ForEach(model.timeline) { entry in
                    TimelineItem(entry.item)
                }
            }
        }
    }

    private var tiles: some View {
        VStack(alignment: .leading, spacing: TonySpacing.inset) {
            sectionTitle(model.tilesTitle)
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: TonySpacing.medium, alignment: .top),
                    count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                ),
                spacing: TonySpacing.inset
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
    TodayScreen(PreviewSamples.today(alert: AlertDataModel(title: "Your answer could not be saved", dismiss: ButtonDataModel(title: "OK", action: Action(id: "preview") { _ in }))))
        .tonyPreview(padding: 0)
}
#endif
