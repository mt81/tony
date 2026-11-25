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
        /// Draws the marker and the reason in the neglected mood.
        public var isNeglected: Bool = false
        /// Set on the task to do now: shown in the accent colour in place of the time, with an accent marker.
        public var now: String? = nil
        public var accessibilityIdentifier: String? = nil
    }

    /// What is already done today, above the rest of the day.
    case done(text: String)
    case now(text: String)
    case task(TaskItem, isLast: Bool)
    case meetings(time: String, title: String, detail: String)
}

@MemberwiseInit(.public)
public struct TileDataModel: Hashable, Sendable {
    /// The Figma area colours a tile can take.
    public enum Colour: Hashable, Sendable, CaseIterable {
        case yellow, green, blue, orange, teal, indigo
    }

    public var icon: String
    public var title: String
    public var detail: String
    public var colour: Colour
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

/// A form row that opens a page: an icon, what it sets, and its value.
@MemberwiseInit(.public)
public struct DetailRowDataModel: Hashable, Sendable {
    /// An SF Symbol.
    public var systemImage: String
    public var title: String
    public var value: String
    public var accessibilityIdentifier: String? = nil
}

/// A box to type a sentence in, with a button that sends it.
@MemberwiseInit(.public)
public struct ComposerDataModel: Equatable {
    public var text: TextFieldDataModel
    /// Disabled while there is nothing to send.
    public var send: ButtonDataModel
    /// The sentence was sent and its answer has not come back.
    public var isSending: Bool
}

/// Where calendar access stands, and the button that asks for it, if any.
@MemberwiseInit(.public)
public struct CalendarCardDataModel: Equatable {
    public var title: String
    public var text: String
    public var textAccessibilityIdentifier: String? = nil
    public var allow: ButtonDataModel?
}

/// A large drawing that says what a screen is about.
public enum Illustration: Sendable, CaseIterable {
    case tony
}
