import Foundation
import Testing
import TonyCore
@testable import TonyPresentation

private struct FixedCalendarSource: CalendarSource {
    var currentAccess: CalendarAccess
    var busy: [DateInterval] = []

    func access() -> CalendarAccess { currentAccess }
    func requestAccess() -> CalendarAccess { currentAccess }
    func busyIntervals(in interval: DateInterval) -> [DateInterval] { currentAccess == .granted ? busy : [] }
    func changes() -> AsyncStream<Void> { AsyncStream { _ in } }
}

private func environment(access: CalendarAccess, busy: [DateInterval] = []) throws -> CalendarDebugFeature.Environment {
    let source = FixedCalendarSource(currentAccess: access, busy: busy)
    let now = try Sample.november(2, hour: 8)
    let coordinator = PlanCoordinator(repository: FakeRepository(), calendarSource: source, calendar: Sample.calendar) { now }
    return CalendarDebugFeature.Environment(calendarSource: source, coordinator: coordinator)
}

@Test func appearingAndRefreshingReadTheCalendar() {
    var state = CalendarDebugFeature.State()

    #expect(CalendarDebugFeature.reduce(&state, .appeared) == [.load])
    #expect(CalendarDebugFeature.reduce(&state, .refreshTapped) == [.load])
    #expect(CalendarDebugFeature.reduce(&state, .requestAccessTapped) == [.requestAccess])
}

@MainActor
@Test func busyTimeShowsAsMergedBusyRows() async throws {
    let meetings = [
        DateInterval(start: try Sample.november(2, hour: 10), duration: 1800),
        DateInterval(start: try Sample.november(2, hour: 10).addingTimeInterval(1800), duration: 1800),
    ]
    var state = CalendarDebugFeature.State()
    let loaded = try #require(await CalendarDebugFeature.run(.load, in: try environment(access: .granted, busy: meetings)))
    _ = CalendarDebugFeature.reduce(&state, loaded)

    let model = CalendarDebugFeature.dataModel(for: state, context: try Sample.context(day: 2, language: "en_GB")) { _ in }
    let busyRows = model.rows.filter(\.isBusy)

    #expect(model.access == "Calendar access: granted")
    #expect(model.requestAccess == nil)
    #expect(busyRows.map(\.time) == ["10:00 to 11:00"])
    #expect(busyRows.map(\.detail) == ["Busy · 2 events merged · workday · home"])
    #expect(model.rows.count == 7)
}

@MainActor
@Test func theAccessButtonShowsOnlyBeforeTheUserAnswered() async throws {
    var state = CalendarDebugFeature.State()
    let sent = SentActions<CalendarDebugFeature.Action>()

    let loaded = try #require(await CalendarDebugFeature.run(.load, in: try environment(access: .notDetermined)))
    _ = CalendarDebugFeature.reduce(&state, loaded)
    let undecided = CalendarDebugFeature.dataModel(for: state, context: try Sample.context(day: 2), send: sent.send)
    undecided.requestAccess?.action.execute()
    undecided.refresh.action.execute()

    #expect(undecided.access == "Calendar access: not asked yet")
    #expect(undecided.rows.allSatisfy { !$0.isBusy })
    #expect(sent.actions == [.requestAccessTapped, .refreshTapped])

    _ = CalendarDebugFeature.reduce(&state, .loaded(access: .denied, planned: state.planned))
    #expect(CalendarDebugFeature.dataModel(for: state, context: try Sample.context(day: 2)) { _ in }.requestAccess == nil)
}
