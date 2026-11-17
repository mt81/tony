import Foundation

// Data models of Tony's own components.

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
        /// Draws the icon and the reason in the neglected mood.
        public var isNeglected: Bool
        public var accessibilityIdentifier: String?

        public init(
            icon: String,
            time: String,
            title: String,
            reason: String,
            actions: [ButtonDataModel] = [],
            check: ButtonDataModel,
            isNeglected: Bool = false,
            accessibilityIdentifier: String? = nil
        ) {
            self.icon = icon
            self.time = time
            self.title = title
            self.reason = reason
            self.actions = actions
            self.check = check
            self.isNeglected = isNeglected
            self.accessibilityIdentifier = accessibilityIdentifier
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

/// One week of "done over suggested", drawn as a path.
public struct ConsistencyDataModel: Hashable, Sendable {
    public struct Day: Identifiable, Hashable, Sendable {
        public enum Kind: Sendable {
            /// A day with a score: a dot on the line.
            case scored
            /// A rest day: it stays on the path.
            case rest
            /// A day that has not happened yet.
            case upcoming
        }

        public var id: Int
        public var letter: String
        public var value: String
        /// From 0 (nothing done) to 1 (everything done): where the day sits in the graph.
        public var level: Double
        public var kind: Kind
        public var isToday: Bool

        public init(id: Int, letter: String, value: String, level: Double, kind: Kind, isToday: Bool) {
            self.id = id
            self.letter = letter
            self.value = value
            self.level = level
            self.kind = kind
            self.isToday = isToday
        }
    }

    public var title: String
    public var caption: String
    public var days: [Day]
    public var footnote: String
    /// What VoiceOver reads for the graph as a whole.
    public var accessibilityLabel: String

    public init(title: String, caption: String, days: [Day], footnote: String, accessibilityLabel: String) {
        self.title = title
        self.caption = caption
        self.days = days
        self.footnote = footnote
        self.accessibilityLabel = accessibilityLabel
    }
}
