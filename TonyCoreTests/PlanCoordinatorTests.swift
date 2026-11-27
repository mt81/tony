import Foundation
import Synchronization
import Testing
@testable import TonyCore

private final class TestClock: Sendable {
    private let date: Mutex<Date>

    init(_ date: Date) {
        self.date = Mutex(date)
    }

    var now: Date { date.withLock { $0 } }

    func set(_ newDate: Date) {
        date.withLock { $0 = newDate }
    }
}

private actor InMemoryRepository: Repository {
    private var storedTasks: [TonyTask]
    private var storedCompletions: [Completion] = []
    private var storedRoutine: Routine?
    private(set) var taskReads = 0
    private var fails = false
    private var holdsNextRead = false
    private var heldRead: CheckedContinuation<Void, Never>?

    init(tasks: [TonyTask], routine: Routine? = nil) {
        storedTasks = tasks
        storedRoutine = routine
    }

    func setFails(_ fails: Bool) { self.fails = fails }

    /// The next read of the tasks waits until `releaseRead()`.
    func holdNextRead() {
        holdsNextRead = true
    }

    /// Lets the held read go on; when no read is waiting yet, the next one does not wait.
    func releaseRead() {
        holdsNextRead = false
        heldRead?.resume()
        heldRead = nil
    }

    func tasks() async throws -> [TonyTask] {
        taskReads += 1
        if holdsNextRead {
            holdsNextRead = false
            await withCheckedContinuation { heldRead = $0 }
        }
        if fails { throw CocoaError(.fileReadUnknown) }
        return storedTasks
    }

    func save(_ task: TonyTask) { storedTasks.append(task) }
    func deleteTask(id: UUID) { storedTasks.removeAll { $0.id == id } }
    func reorderTasks(_ orderedIDs: [UUID]) {}
    func completions() -> [Completion] { storedCompletions }
    func save(_ completion: Completion) { storedCompletions.append(completion) }
    func routine() -> Routine? { storedRoutine }
    func save(_ routine: Routine) { storedRoutine = routine }
    func preferences() -> [Preference] { [] }
    func save(_ preference: Preference) {}
}

/// Answers with a fixed forecast, and counts how often it is asked.
private final class FakeWeatherSource: WeatherSource {
    private let forecast: WeatherCondition?
    private let readCount = Mutex(0)

    init(forecast: WeatherCondition?) {
        self.forecast = forecast
    }

    var reads: Int { readCount.withLock { $0 } }

    func condition(on day: Date, at place: Place) -> WeatherCondition? {
        readCount.withLock { $0 += 1 }
        return forecast
    }
}

/// Saturday 7 November 2026 at 8:00, with two tasks due and an empty calendar.
private struct Setup {
    let clock: TestClock
    let repository: InMemoryRepository
    let calendarSource: FakeCalendarSource
    let weatherSource: FakeWeatherSource
    let coordinator: PlanCoordinator
    let tasks: [TonyTask]

    /// `plantsNeed` is the only weather the first task can be done in.
    init(
        routine: Routine? = nil,
        access: PermissionStatus = .granted,
        forecast: WeatherCondition? = nil,
        plantsNeed: Set<WeatherCondition> = [],
        day: Int = 7
    ) throws {
        tasks = [
            try Fixtures.task(1, "Plants", rank: 0, requirements: Requirements(neededWeather: plantsNeed)),
            try Fixtures.task(2, "Vacuum", rank: 1),
        ]
        let clock = TestClock(try Fixtures.november(day, hour: 8))
        self.clock = clock
        repository = InMemoryRepository(tasks: tasks, routine: routine)
        calendarSource = FakeCalendarSource(access: access)
        weatherSource = FakeWeatherSource(forecast: forecast)
        coordinator = PlanCoordinator(
            repository: repository,
            calendarSource: calendarSource,
            weatherSource: weatherSource,
            calendar: Fixtures.calendar
        ) { clock.now }
    }

    func current() async throws -> PlannedDay {
        try #require(await coordinator.current)
    }
}

@Test func startingPublishesAPlanForTheDay() async throws {
    let setup = try Setup()
    var plans = await setup.coordinator.plans().makeAsyncIterator()

    await setup.coordinator.start()

    let planned = try #require(await plans.next())
    #expect(planned.plan.items.map(\.taskID) == setup.tasks.map(\.id))
    #expect(planned.plannedAt == (try Fixtures.november(7, hour: 8)))
    #expect(planned == (try await setup.current()))
}

@Test func aNewSubscriberGetsTheLatestPlanRightAway() async throws {
    let setup = try Setup()
    await setup.coordinator.start()

    var plans = await setup.coordinator.plans().makeAsyncIterator()

    #expect(await plans.next() == (try await setup.current()))
}

@Test func theStandardRoutineIsUsedUntilOneIsSaved() async throws {
    let withoutRoutine = try Setup(day: 3)
    await withoutRoutine.coordinator.start()
    #expect(try await withoutRoutine.current().context.blocks.allSatisfy { $0.location == .home })

    let withRoutine = try Setup(routine: Fixtures.routine(), day: 3)
    await withRoutine.coordinator.start()
    #expect(try await withRoutine.current().context.blocks.allSatisfy { $0.location == .office })
}

@Test func recordingDoneYieldsAPlanWithoutThatTask() async throws {
    let setup = try Setup()
    await setup.coordinator.start()
    let first = try #require(try await setup.current().plan.items.first)

    try await setup.coordinator.record(.done, on: first)

    #expect(try await setup.current().plan.items.map(\.taskID) == [setup.tasks[1].id])
    #expect(try await setup.current().completions.contains { $0.taskID == first.taskID && $0.outcome == .done })
}

@Test func aStatusChangeYieldsANewPlanAndLastsOnlyThatDay() async throws {
    let setup = try Setup()
    await setup.coordinator.start()

    await setup.coordinator.setStatus(.offDay)
    #expect(try await setup.current().context.capacity == .off)
    #expect(try await setup.current().plan.items.isEmpty)

    setup.clock.set(try Fixtures.november(8, hour: 8))
    await setup.coordinator.refresh()
    #expect(try await setup.current().context.capacity == .full)
    #expect(try await setup.current().plan.items.count == 2)
}

@Test func aCalendarChangeYieldsANewPlan() async throws {
    let setup = try Setup()
    await setup.coordinator.start()
    var plans = await setup.coordinator.plans().makeAsyncIterator()
    _ = await plans.next()

    let meeting = DateInterval(start: try Fixtures.november(7, hour: 8), duration: 3600)
    setup.calendarSource.replaceEvents([CalendarEvent(interval: meeting)])

    let planned = try #require(await plans.next())
    #expect(planned.context.blocks.filter { $0.availability == .busy }.map(\.interval) == [meeting])
    #expect(planned.plan.items.first?.interval.start == meeting.end)
}

@Test func comingBackLaterPlansTheRestOfTheDay() async throws {
    let setup = try Setup()
    await setup.coordinator.start()
    #expect(try await setup.current().plan.items.first?.interval.start == (try Fixtures.november(7, hour: 8)))

    setup.clock.set(try Fixtures.november(7, hour: 14))
    await setup.coordinator.refresh()

    #expect(try await setup.current().plan.items.first?.interval.start == (try Fixtures.november(7, hour: 14)))
}

/// Signals once the expected number of requests has arrived.
private final class Arrivals: Sendable {
    private let count = Mutex(0)
    private let expected: Int
    let all: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init(expected: Int) {
        self.expected = expected
        (all, continuation) = AsyncStream.makeStream(of: Void.self)
    }

    func arrive() {
        if count.withLock({ count in
            count += 1
            return count
        }) == expected {
            continuation.finish()
        }
    }
}

extension PlanCoordinator {
    /// Counts the request, then makes it, in one turn of the coordinator: once counted, the request has arrived.
    fileprivate func refresh(counting arrivals: Arrivals) async {
        arrivals.arrive()
        await refresh()
    }
}

@Test func rapidEventsDoNotPlanOncePerEvent() async throws {
    let setup = try Setup()
    await setup.coordinator.start()
    let readsBefore = await setup.repository.taskReads
    let arrivals = Arrivals(expected: 25)
    await setup.repository.holdNextRead()

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<25 {
            group.addTask { await setup.coordinator.refresh(counting: arrivals) }
        }
        // The first plan waits until every request has arrived, so they all arrive while it is being made.
        for await _ in arrivals.all {}
        await setup.repository.releaseRead()
    }

    let passes = await setup.repository.taskReads - readsBefore
    #expect((1...2).contains(passes))
}

@Test func withoutCalendarAccessTheDayIsPlannedWithNoBusyTime() async throws {
    let setup = try Setup(access: .denied)
    setup.calendarSource.replaceEvents([CalendarEvent(interval: DateInterval(start: try Fixtures.november(7, hour: 8), duration: 3600))])

    await setup.coordinator.start()

    #expect(try await setup.current().context.blocks.allSatisfy { $0.availability != .busy })
    #expect(try await setup.current().plan.items.count == 2)
}

@Test func aStoreFailureKeepsThePreviousPlan() async throws {
    let setup = try Setup()
    await setup.coordinator.start()
    let before = try await setup.current()

    await setup.repository.setFails(true)
    setup.clock.set(try Fixtures.november(7, hour: 14))
    await setup.coordinator.refresh()

    #expect(try await setup.current() == before)
}

@Test(arguments: [
    (WeatherCondition?.some(.rain), false),
    (.thunder, false),
    (.clear, true),
    (.fair, true),
    (nil, true),
])
func theDaysWeatherDecidesWhetherATaskThatNeedsSomeIsPlanned(forecast: WeatherCondition?, isPlanned: Bool) async throws {
    let setup = try Setup(routine: Fixtures.routineWithPlace, forecast: forecast, plantsNeed: [.clear, .fair])

    await setup.coordinator.start()

    let planned = try await setup.current()
    #expect(planned.context.conditions.weather == forecast)
    #expect(planned.plan.items.contains { $0.taskID == setup.tasks[0].id } == isPlanned)
    #expect(planned.plan.items.contains { $0.taskID == setup.tasks[1].id })
}

@Test func theWeatherIsReadOnlyWhenATaskNeedsSome() async throws {
    let setup = try Setup(routine: Fixtures.routineWithPlace, forecast: .rain)

    await setup.coordinator.start()

    #expect(setup.weatherSource.reads == 0)
    #expect(try await setup.current().context.conditions.weather == nil)
}

@Test func theWeatherIsReadOnlyWhenAPlaceIsSaved() async throws {
    let setup = try Setup(forecast: .rain, plantsNeed: [.clear])

    await setup.coordinator.start()

    #expect(setup.weatherSource.reads == 0)
    #expect(try await setup.current().plan.items.contains { $0.taskID == setup.tasks[0].id })
}
