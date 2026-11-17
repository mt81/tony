import Foundation

public enum CalendarAccess: String, Sendable, CaseIterable {
    case notDetermined
    case granted
    case denied
}

/// The user's calendars, as far as planning needs them: when they are busy, never what the events are about.
public protocol CalendarSource: Sendable {
    func access() async -> CalendarAccess
    /// Asks the user for access if they have not answered yet, and returns where things stand.
    func requestAccess() async -> CalendarAccess
    /// Busy time inside the interval, across all calendars. Empty when access is not granted.
    func busyIntervals(in interval: DateInterval) async throws -> [DateInterval]
    /// Yields each time the calendars change.
    func changes() -> AsyncStream<Void>
}

/// The few facts read from a calendar event. It has no title, place or people.
public struct CalendarEvent: Sendable, Hashable {
    public enum ShowsAs: String, Sendable, CaseIterable {
        case busy
        case tentative
        case unavailable
        case free
    }

    public var interval: DateInterval
    public var isAllDay: Bool
    public var showsAs: ShowsAs
    public var isCancelled: Bool
    /// The user declined the invitation.
    public var isDeclined: Bool

    public init(interval: DateInterval, isAllDay: Bool = false, showsAs: ShowsAs = .busy, isCancelled: Bool = false, isDeclined: Bool = false) {
        self.interval = interval
        self.isAllDay = isAllDay
        self.showsAs = showsAs
        self.isCancelled = isCancelled
        self.isDeclined = isDeclined
    }

    /// Timed events the user has not declined count as busy, tentative ones included.
    /// All-day events would block the whole day, so they do not.
    public var isBusy: Bool {
        !isAllDay && !isCancelled && !isDeclined && showsAs != .free
    }
}

extension Sequence<CalendarEvent> {
    /// The busy time of these events inside the interval, in start order.
    public func busyIntervals(in interval: DateInterval) -> [DateInterval] {
        filter(\.isBusy)
            .compactMap { $0.interval.intersection(with: interval) }
            .filter { $0.duration > 0 }
            .sorted { $0.start < $1.start }
    }
}
