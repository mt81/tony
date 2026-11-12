import Foundation

/// The usual week. Times of day are hour and minute components, resolved against a calendar when a day is built.
public struct Routine: Codable, Sendable, Hashable {
    public var homeDays: Set<Locale.Weekday>
    public var officeDays: Set<Locale.Weekday>
    public var workStart: DateComponents
    public var workEnd: DateComponents
    public var wakeTime: DateComponents
    public var bedtime: DateComponents

    public init(
        homeDays: Set<Locale.Weekday>,
        officeDays: Set<Locale.Weekday>,
        workStart: DateComponents,
        workEnd: DateComponents,
        wakeTime: DateComponents,
        bedtime: DateComponents
    ) {
        self.homeDays = homeDays
        self.officeDays = officeDays
        self.workStart = workStart
        self.workEnd = workEnd
        self.wakeTime = wakeTime
        self.bedtime = bedtime
    }
}
