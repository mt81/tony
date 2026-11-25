import Foundation
import MemberwiseInit

/// The user's calendars, as far as planning needs them: when they are busy, never what the events are about.
/// Access is asked through the calendar's `PermissionProvider`.
public protocol CalendarSource: Sendable {
    /// Busy time inside the interval, across all calendars. Empty when access is not granted.
    func busyIntervals(in interval: DateInterval) async throws -> [DateInterval]
    /// Yields each time the calendars change.
    func changes() -> AsyncStream<Void>
}

/// The few facts read from a calendar event. It has no title, place or people.
@MemberwiseInit(.public)
public struct CalendarEvent: Sendable, Hashable {
    public enum ShowsAs: String, Sendable, CaseIterable {
        case busy
        case tentative
        case unavailable
        case free
    }

    public var interval: DateInterval
    public var isAllDay: Bool = false
    public var showsAs: ShowsAs = .busy
    public var isCancelled: Bool = false
    /// The user declined the invitation.
    public var isDeclined: Bool = false

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
