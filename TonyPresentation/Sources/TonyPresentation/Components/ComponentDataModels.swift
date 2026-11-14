import Foundation
import TonyUIKit

// Data models of Tony's own components. TonyDesign draws them.

public struct ChipDataModel: Hashable, Sendable {
    public enum Style: Sendable, CaseIterable {
        case neutral
        case selected
        case accent
        case warning
    }

    public var title: String
    public var style: Style

    public init(title: String, style: Style = .neutral) {
        self.title = title
        self.style = style
    }
}

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
    public var open: @MainActor () -> Void
    public var delete: ButtonDataModel

    public init(
        id: UUID,
        icon: String,
        title: String,
        subtitle: String,
        status: ChipDataModel,
        isNeglected: Bool,
        accessibilityIdentifier: String,
        open: @escaping @MainActor () -> Void,
        delete: ButtonDataModel
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.isNeglected = isNeglected
        self.accessibilityIdentifier = accessibilityIdentifier
        self.open = open
        self.delete = delete
    }
}

/// One entry of the Today timeline.
public enum TimelineItemDataModel {
    public struct TaskItem {
        public var icon: String
        public var time: String
        public var title: String
        public var reason: String
        public var actions: [ButtonDataModel]
        /// Marks the item as done; its title is the VoiceOver label.
        public var check: ButtonDataModel

        public init(icon: String, time: String, title: String, reason: String, actions: [ButtonDataModel] = [], check: ButtonDataModel) {
            self.icon = icon
            self.time = time
            self.title = title
            self.reason = reason
            self.actions = actions
            self.check = check
        }
    }

    case now(text: String)
    case task(TaskItem, isLast: Bool)
    case meetings(time: String, title: String, detail: String)
}

public struct TileDataModel: Hashable, Sendable {
    public var icon: String
    public var title: String
    public var detail: String
    public var isNeglected: Bool

    public init(icon: String, title: String, detail: String, isNeglected: Bool = false) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.isNeglected = isNeglected
    }
}

public struct StatDataModel: Hashable, Sendable {
    public var value: String
    public var label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

public struct AreaRowDataModel: Hashable, Sendable {
    public var name: String
    /// From 0 to 1.
    public var progress: Double
    public var status: String

    public init(name: String, progress: Double, status: String) {
        self.name = name
        self.progress = progress
        self.status = status
    }
}
