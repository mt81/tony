import Foundation
import MemberwiseInit

public enum DayStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case normal
    case offDay
    case sick
    case travelling
}

@MemberwiseInit(.public)
public struct DayConditions: Codable, Sendable, Hashable {
    public var weather: WeatherCondition? = nil
    public var budgetIsTight: Bool = false
}

/// One day as the planner sees it: time blocks in order, covering the whole day.
@MemberwiseInit(.public)
public struct DayContext: Codable, Sendable, Hashable {
    @MemberwiseInit(.public)
    public struct Block: Codable, Sendable, Hashable {
        public var interval: DateInterval
        public var location: Location
        public var availability: Availability
        public var window: Window
        /// How many calendar events were merged into a busy block; zero for the others.
        public var eventCount: Int = 0
    }

    public var blocks: [Block]
    public var capacity: Capacity
    public var conditions: DayConditions
}
