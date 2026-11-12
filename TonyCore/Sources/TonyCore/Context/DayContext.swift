import Foundation

public enum DayStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case normal
    case offDay
    case sick
    case travelling
}

public struct DayConditions: Codable, Sendable, Hashable {
    public var weather: WeatherCondition?
    public var budgetIsTight: Bool

    public init(weather: WeatherCondition? = nil, budgetIsTight: Bool = false) {
        self.weather = weather
        self.budgetIsTight = budgetIsTight
    }
}

/// One day as the planner sees it: time blocks in order, covering the whole day.
public struct DayContext: Codable, Sendable, Hashable {
    public struct Block: Codable, Sendable, Hashable {
        public var interval: DateInterval
        public var location: Location
        public var availability: Availability
        public var window: Window
        /// How many calendar events were merged into a busy block; zero for the others.
        public var eventCount: Int

        public init(interval: DateInterval, location: Location, availability: Availability, window: Window, eventCount: Int = 0) {
            self.interval = interval
            self.location = location
            self.availability = availability
            self.window = window
            self.eventCount = eventCount
        }
    }

    public var blocks: [Block]
    public var capacity: Capacity
    public var conditions: DayConditions

    public init(blocks: [Block], capacity: Capacity, conditions: DayConditions) {
        self.blocks = blocks
        self.capacity = capacity
        self.conditions = conditions
    }
}
