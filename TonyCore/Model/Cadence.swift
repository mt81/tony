import Foundation
import MemberwiseInit

public enum Cadence: Codable, Sendable, Hashable {
    /// Every so many days, weeks, months or years.
    case interval(Interval, countedFrom: Anchor)
    /// On these weekdays, every week.
    case weekdays(Set<Locale.Weekday>)
    /// A weekly goal: this many sessions in any week.
    case timesPerWeek(Int)

    @MemberwiseInit(.public)
    public struct Interval: Codable, Sendable, Hashable {
        public enum Unit: String, Codable, Sendable, Hashable, CaseIterable {
            case day
            case week
            case month
            case year
        }

        public var count: Int
        public var unit: Unit
    }

    public enum Anchor: Codable, Sendable, Hashable {
        /// The next time comes one interval after the last time it was done.
        case lastCompletion
        /// The task comes due on this day and every interval after it, whenever it was last done.
        case schedule(from: Date)
    }

    /// Every so many units, counted from the last time it was done.
    public static func every(_ count: Int, _ unit: Interval.Unit) -> Cadence {
        .interval(Interval(count: count, unit: unit), countedFrom: .lastCompletion)
    }
}

extension Cadence.Interval.Unit {
    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    /// The length of one unit in days, for neglect.
    var approximateDays: Double {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
        case .year: 365
        }
    }

    /// The largest count the task form offers.
    public var maximumCount: Int {
        switch self {
        case .day: 365
        case .week: 52
        case .month: 24
        case .year: 10
        }
    }
}
