import Foundation

public enum Cadence: Codable, Sendable, Hashable {
    case afterCompletion(days: Int)
    case weekdays(Set<Locale.Weekday>)
    case timesPerWeek(Int)
}
