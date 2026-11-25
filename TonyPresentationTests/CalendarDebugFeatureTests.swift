import Foundation
import Testing
import TonyCore
@testable import TonyPresentation

@MainActor
private func environment(
    access: PermissionStatus,
    busy: [DateInterval] = [],
    tasks: [TonyTask] = [],
    forecast: WeatherCondition? = nil
) throws -> CalendarDebugFeature.Environment {
    let source = FakeCalendarSource(busyIntervals: access == .granted ? busy : [])
    let now = try Sample.november(2, hour: 8)
    let repository = FakeRepository(tasks: tasks)
    let coordinator = PlanCoordinator(
        repository: repository,
        calendarSource: source,
        weatherSource: FakeWeatherSource(forecast: forecast),
        calendar: Sample.calendar
    ) { now }
    return CalendarDebugFeature.Environment(permissions: .fake(FakePermissionProvider(status: access)), repository: repository, coordinator: coordinator)
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

    _ = CalendarDebugFeature.reduce(&state, .loaded(access: .denied, planned: state.planned, place: nil))
    #expect(CalendarDebugFeature.dataModel(for: state, context: try Sample.context(day: 2)) { _ in }.requestAccess == nil)
}

@MainActor
@Test func choosingACitySavesItAndTheWeatherLineShowsWhatThePlannerSaw() async throws {
    var outdoor = try Sample.task(1, "Run")
    outdoor.requirements.neededWeather = [.clear]
    let environment = try environment(access: .granted, tasks: [outdoor], forecast: .rain)
    let context = try Sample.context(day: 2)
    var state = CalendarDebugFeature.State()
    let sent = SentActions<CalendarDebugFeature.Action>()

    #expect(CalendarDebugFeature.dataModel(for: state, context: context) { _ in }.weather == "Weather: checking")

    let empty = try #require(await CalendarDebugFeature.run(.load, in: environment))
    _ = CalendarDebugFeature.reduce(&state, empty)
    let before = CalendarDebugFeature.dataModel(for: state, context: context, send: sent.send)
    before.places.first?.action.execute()
    #expect(before.weather == "Weather: no city saved")
    #expect(before.places.map(\.title) == ["Use Paris", "Use Toronto", "Use Oslo", "Clear the city"])

    let paris = try #require(CalendarDebugFeature.sampleCities.first)
    #expect(sent.actions == [.placeChosen(paris)])
    #expect(CalendarDebugFeature.reduce(&state, .placeChosen(paris)) == [.savePlace(paris)])
    let saved = try #require(await CalendarDebugFeature.run(.savePlace(paris), in: environment))
    _ = CalendarDebugFeature.reduce(&state, saved)

    #expect(try await environment.repository.routine()?.place == paris)
    #expect(CalendarDebugFeature.dataModel(for: state, context: context) { _ in }.weather == "Weather today in Paris: rain")
}
