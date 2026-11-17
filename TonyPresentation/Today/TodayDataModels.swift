import Foundation
import TonyUIModels

/// The Today tab: Tony, the briefing, the day as a timeline, and the tiles.
public struct TodayScreenDataModel {
    public struct TimelineEntry: Identifiable {
        public var id: String
        public var item: TimelineItemDataModel

        public init(id: String, item: TimelineItemDataModel) {
            self.id = id
            self.item = item
        }
    }

    public struct IdentifiedTile: Identifiable, Hashable, Sendable {
        public var id: UUID
        public var tile: TileDataModel

        public init(id: UUID, tile: TileDataModel) {
            self.id = id
            self.tile = tile
        }
    }

    public var date: String
    public var headline: String
    public var briefing: BriefingDataModel
    public var timelineTitle: String
    public var timelineHint: String
    public var timeline: [TimelineEntry]
    public var addTask: ButtonDataModel
    public var tilesTitle: String
    public var tiles: [IdentifiedTile]
    /// The task form, while a task is being added.
    public var editor: TaskEditorDataModel?
    public var dismissEditor: @MainActor () -> Void
    public var alert: AlertDataModel?
    public var onAppear: @MainActor () -> Void

    public init(
        date: String,
        headline: String,
        briefing: BriefingDataModel,
        timelineTitle: String,
        timelineHint: String,
        timeline: [TimelineEntry],
        addTask: ButtonDataModel,
        tilesTitle: String,
        tiles: [IdentifiedTile],
        editor: TaskEditorDataModel?,
        dismissEditor: @escaping @MainActor () -> Void,
        alert: AlertDataModel?,
        onAppear: @escaping @MainActor () -> Void
    ) {
        self.date = date
        self.headline = headline
        self.briefing = briefing
        self.timelineTitle = timelineTitle
        self.timelineHint = timelineHint
        self.timeline = timeline
        self.addTask = addTask
        self.tilesTitle = tilesTitle
        self.tiles = tiles
        self.editor = editor
        self.dismissEditor = dismissEditor
        self.alert = alert
        self.onAppear = onAppear
    }
}

/// What Tony says about the day.
public struct BriefingDataModel {
    public var author: String
    public var time: String
    public var text: String

    public init(author: String, time: String, text: String) {
        self.author = author
        self.time = time
        self.text = text
    }
}
