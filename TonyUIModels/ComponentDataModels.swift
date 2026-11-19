import Foundation
import MemberwiseInit

// Data models of Tony's own components.

@MemberwiseInit(.public)
public struct ChipDataModel: Hashable, Sendable {
    public enum Style: Sendable, CaseIterable {
        case neutral
        case selected
        case accent
        case warning
    }

    public var title: String
    public var style: Style = .neutral
}

@MemberwiseInit(.public)
public struct TaskRowDataModel: Identifiable {
    public var id: UUID
    /// The task's emoji.
    public var icon: String
    public var title: String
    public var subtitle: String
    public var status: ChipDataModel
    /// Draws the icon in the neglected mood.
    public var isNeglected: Bool
    public var accessibilityIdentifier: String
    public var open: any Executable<Void>
    public var delete: ButtonDataModel
}

/// One entry of the Today timeline.
public enum TimelineItemDataModel: Equatable {
    @MemberwiseInit(.public)
    public struct TaskItem: Equatable {
        public var icon: String
        public var time: String
        public var title: String
        public var reason: String
        public var actions: [ButtonDataModel] = []
        /// Marks the item as done; its title is the VoiceOver label.
        public var check: ButtonDataModel
        /// Draws the icon and the reason in the neglected mood.
        public var isNeglected: Bool = false
        public var accessibilityIdentifier: String? = nil
    }

    case now(text: String)
    case task(TaskItem, isLast: Bool)
    case meetings(time: String, title: String, detail: String)
}

@MemberwiseInit(.public)
public struct TileDataModel: Hashable, Sendable {
    public var icon: String
    public var title: String
    public var detail: String
    public var isNeglected: Bool = false
}

@MemberwiseInit(.public)
public struct StatDataModel: Hashable, Sendable {
    public var value: String
    public var label: String
}

@MemberwiseInit(.public)
public struct AreaRowDataModel: Hashable, Sendable {
    public var name: String
    /// From 0 to 1.
    public var progress: Double
    public var status: String
}

extension TaskRowDataModel: Equatable {
    public static func == (lhs: TaskRowDataModel, rhs: TaskRowDataModel) -> Bool {
        lhs.id == rhs.id
            && lhs.icon == rhs.icon
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.status == rhs.status
            && lhs.isNeglected == rhs.isNeglected
            && lhs.accessibilityIdentifier == rhs.accessibilityIdentifier
            && lhs.delete == rhs.delete
            && lhs.open.isEqual(to: rhs.open)
    }
}
