import Foundation
import MemberwiseInit

/// The usual week. Times of day are hour and minute components, resolved against a calendar when a day is built.
@MemberwiseInit(.public)
public struct Routine: Codable, Sendable, Hashable {
    public var homeDays: Set<Locale.Weekday>
    public var officeDays: Set<Locale.Weekday>
    public var workStart: DateComponents
    public var workEnd: DateComponents
    public var wakeTime: DateComponents
    public var bedtime: DateComponents
}
