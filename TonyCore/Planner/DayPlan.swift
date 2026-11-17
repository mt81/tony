import Foundation
import MemberwiseInit

/// What the planner suggests for the rest of a day, in time order.
@MemberwiseInit(.public)
public struct DayPlan: Codable, Sendable, Hashable {
    /// Why an item sits where it does. Tony puts this into words; the timeline shows it under the title.
    public enum Reason: String, Codable, Sendable, Hashable, CaseIterable {
        case beforeBlock
        case afterBlock
        case needsEvening
        case earliestFit
    }

    @MemberwiseInit(.public)
    public struct Item: Codable, Sendable, Hashable, Identifiable {
        public var taskID: UUID
        public var stepID: UUID
        public var interval: DateInterval
        /// The last moment the step can start for the rest of its task to still fit today.
        public var latestStart: Date
        public var reason: Reason

        public var id: UUID { stepID }
    }

    public var items: [Item]
}

/// What the user can answer to a suggested item.
public enum PlanAction: String, Codable, Sendable, Hashable, CaseIterable {
    case done
    case later
    case notToday
}
