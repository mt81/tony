import Foundation
import MemberwiseInit
import TonyUIModels

/// The Today tab: Tony, the briefing, the day as a timeline, and the tiles.
@MemberwiseInit(.public)
public struct TodayScreenDataModel {
    @MemberwiseInit(.public)
    public struct TimelineEntry: Identifiable {
        public var id: String
        public var item: TimelineItemDataModel
    }

    @MemberwiseInit(.public)
    public struct IdentifiedTile: Identifiable, Hashable, Sendable {
        public var id: UUID
        public var tile: TileDataModel
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
}

/// What Tony says about the day.
@MemberwiseInit(.public)
public struct BriefingDataModel {
    public var author: String
    public var time: String
    public var text: String
}
