import Foundation
import Testing
@testable import TonyCore

/// Answers from a fixed list of events, with the same busy rules as the real adapter.
final class FakeCalendarSource: CalendarSource, @unchecked Sendable {
    // Guarded by the lock.
    private let lock = NSLock()
    private var currentAccess: CalendarAccess
    private var events: [CalendarEvent]
    private var continuations: [AsyncStream<Void>.Continuation] = []
    private let accessAfterRequest: CalendarAccess

    init(events: [CalendarEvent] = [], access: CalendarAccess = .granted, accessAfterRequest: CalendarAccess = .granted) {
        self.events = events
        self.currentAccess = access
        self.accessAfterRequest = accessAfterRequest
    }

    func access() -> CalendarAccess {
        lock.withLock { currentAccess }
    }

    func requestAccess() -> CalendarAccess {
        lock.withLock {
            if currentAccess == .notDetermined {
                currentAccess = accessAfterRequest
            }
            return currentAccess
        }
    }

    func busyIntervals(in interval: DateInterval) -> [DateInterval] {
        lock.withLock { currentAccess == .granted ? events.busyIntervals(in: interval) : [] }
    }

    func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            lock.withLock { continuations.append(continuation) }
        }
    }

    func replaceEvents(_ newEvents: [CalendarEvent]) {
        let waiting = lock.withLock {
            events = newEvents
            return continuations
        }
        waiting.forEach { $0.yield() }
    }
}

private func event(
    _ startHour: Int,
    _ startMinute: Int = 0,
    minutes: Double = 60,
    day: Int = 2,
    isAllDay: Bool = false,
    showsAs: CalendarEvent.ShowsAs = .busy,
    isCancelled: Bool = false,
    isDeclined: Bool = false
) throws -> CalendarEvent {
    CalendarEvent(
        interval: DateInterval(start: try Fixtures.november(day, hour: startHour, minute: startMinute), duration: minutes * 60),
        isAllDay: isAllDay,
        showsAs: showsAs,
        isCancelled: isCancelled,
        isDeclined: isDeclined
    )
}

private func monday() throws -> DateInterval {
    DateInterval(start: try Fixtures.november(2), end: try Fixtures.november(3))
}

@Test(arguments: [
    (showsAs: CalendarEvent.ShowsAs.busy, isAllDay: false, isCancelled: false, isDeclined: false, isBusy: true),
    (showsAs: .tentative, isAllDay: false, isCancelled: false, isDeclined: false, isBusy: true),
    (showsAs: .unavailable, isAllDay: false, isCancelled: false, isDeclined: false, isBusy: true),
    (showsAs: .free, isAllDay: false, isCancelled: false, isDeclined: false, isBusy: false),
    (showsAs: .busy, isAllDay: true, isCancelled: false, isDeclined: false, isBusy: false),
    (showsAs: .busy, isAllDay: false, isCancelled: true, isDeclined: false, isBusy: false),
    (showsAs: .busy, isAllDay: false, isCancelled: false, isDeclined: true, isBusy: false),
])
func onlyTimedEventsTheUserKeepsAreBusy(showsAs: CalendarEvent.ShowsAs, isAllDay: Bool, isCancelled: Bool, isDeclined: Bool, isBusy: Bool) throws {
    let event = try event(10, isAllDay: isAllDay, showsAs: showsAs, isCancelled: isCancelled, isDeclined: isDeclined)

    #expect(event.isBusy == isBusy)
}

@Test func busyIntervalsAreClippedToTheDayAndSorted() throws {
    let source = FakeCalendarSource(events: [
        try event(13, minutes: 30),
        try event(23, minutes: 120),
        try event(9, day: 3),
        try event(10, minutes: 20),
    ])

    let intervals = source.busyIntervals(in: try monday())

    #expect(intervals == [
        DateInterval(start: try Fixtures.november(2, hour: 10), duration: 20 * 60),
        DateInterval(start: try Fixtures.november(2, hour: 13), duration: 30 * 60),
        DateInterval(start: try Fixtures.november(2, hour: 23), end: try Fixtures.november(3)),
    ])
}

@Test func aFeedOfBusyTimesBecomesBusyBlocksInTheDay() throws {
    let source = FakeCalendarSource(events: [
        try event(10, minutes: 20),
        try event(10, 20, minutes: 20),
        try event(10, 40, minutes: 20),
        try event(13, minutes: 30),
        try event(15, showsAs: .free),
        try event(0, minutes: 24 * 60, isAllDay: true),
    ])

    let context = try Fixtures.dayContext(day: 2, busyIntervals: source.busyIntervals(in: try monday()))
    let busyBlocks = context.blocks.filter { $0.availability == .busy }

    #expect(busyBlocks.map(\.interval) == [
        DateInterval(start: try Fixtures.november(2, hour: 10), end: try Fixtures.november(2, hour: 11)),
        DateInterval(start: try Fixtures.november(2, hour: 13), duration: 30 * 60),
    ])
    #expect(busyBlocks.map(\.eventCount) == [3, 1])
}

@Test(arguments: [CalendarAccess.notDetermined, .denied])
func withoutAccessNothingIsBusy(access: CalendarAccess) throws {
    let source = FakeCalendarSource(events: [try event(10)], access: access)

    #expect(source.busyIntervals(in: try monday()).isEmpty)
}

@Test(arguments: [
    (before: CalendarAccess.notDetermined, answer: CalendarAccess.granted, after: CalendarAccess.granted),
    (before: .notDetermined, answer: .denied, after: .denied),
    (before: .denied, answer: .granted, after: .denied),
    (before: .granted, answer: .denied, after: .granted),
])
func askingForAccessOnlyChangesAnUndecidedAnswer(before: CalendarAccess, answer: CalendarAccess, after: CalendarAccess) {
    let source = FakeCalendarSource(access: before, accessAfterRequest: answer)

    #expect(source.requestAccess() == after)
    #expect(source.access() == after)
}

@Test func aCalendarChangeIsAnnounced() async throws {
    let source = FakeCalendarSource()
    var changes = source.changes().makeAsyncIterator()

    source.replaceEvents([try event(10)])
    await changes.next()

    #expect(source.busyIntervals(in: try monday()).count == 1)
}
