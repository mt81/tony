import Foundation
import Testing
import TonyCore
import TonyUIModels
@testable import TonyPresentation

/// Tuesday 10 November 2026, a working day at home: free until 9:00, then again from 17:00.
@MainActor
private struct Day {
    let clock: TestClock
    let repository: FakeRepository
    let store: Store<TodayFeature>

    init(hour: Int, tasks: [TonyTask], meetings: [DateInterval] = []) throws {
        let clock = TestClock(try Sample.november(10, hour: hour))
        self.clock = clock
        repository = FakeRepository(tasks: tasks)
        let coordinator = PlanCoordinator(
            repository: repository,
            calendarSource: FakeCalendarSource(busyIntervals: meetings),
            calendar: Sample.calendar
        ) { clock.now }
        store = Store(state: TodayFeature.State(), environment: TodayFeature.Environment(coordinator: coordinator))
    }

    func open(language: String = "en_GB") async -> TodayScreenDataModel {
        store.send(.appeared)
        await store.waitForEffects()
        return model(language: language)
    }

    func model(language: String = "en_GB") -> TodayScreenDataModel {
        store.dataModel(context: PresentationContext(now: clock.now, calendar: Sample.calendar, locale: Locale(identifier: language)))
    }
}

extension TodayScreenDataModel {
    fileprivate var taskItems: [TimelineItemDataModel.TaskItem] {
        timeline.compactMap { entry in
            if case .task(let item, _) = entry.item { item } else { nil }
        }
    }

    fileprivate var meetings: [String] {
        timeline.compactMap { entry in
            if case .meetings(let time, let title, let detail) = entry.item { "\(time) \(title) \(detail)" } else { nil }
        }
    }
}

private func morningMeetings() throws -> [DateInterval] {
    let ten = try Sample.november(10, hour: 10)
    return [0, 20, 40].map { DateInterval(start: ten.addingTimeInterval($0 * 60), duration: 20 * 60) }
}

// MARK: Reducer

@Test func appearingAsksForThePlanAndFillsTheMockedParts() {
    var state = TodayFeature.State()

    #expect(TodayFeature.reduce(&state, .appeared) == [.plan])
    #expect(state.mocked == .sample)
}

@Test func answeringTheQuestionRemovesItForGood() {
    var state = TodayFeature.State()
    _ = TodayFeature.reduce(&state, .appeared)

    _ = TodayFeature.reduce(&state, .questionAnswered)
    _ = TodayFeature.reduce(&state, .appeared)

    #expect(state.mocked?.question == nil)
    #expect(state.mocked?.userName == "Matteo")
}

@MainActor
@Test func aMissingPlanKeepsTheOneOnScreen() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants")])
    _ = await day.open()
    let planned = day.store.state.planned

    day.store.send(.planned(nil))

    #expect(planned != nil)
    #expect(day.store.state.planned == planned)
}

// MARK: Done when

@MainActor
@Test func openingAtEightAndAtTwoShowsDifferentPlans() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")], meetings: try morningMeetings())

    let morning = await day.open()
    day.clock.set(try Sample.november(10, hour: 14))
    let afternoon = await day.open()

    #expect(morning.taskItems.map(\.time) == ["8:00", "8:30"])
    #expect(morning.meetings == ["10:00 3 meetings, back to back Daily scrum · Weekly sync · 1 more · until 11:00"])
    #expect(morning.briefing.time == "· 8:00")
    #expect(afternoon.taskItems.map(\.time) == ["17:00", "17:30"])
    #expect(afternoon.meetings.isEmpty)
    #expect(afternoon.briefing.time == "· 14:00")
}

@MainActor
@Test func checkingAnItemEarlyFreesItsSlot() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")])
    let before = await day.open()

    before.taskItems[0].check.action()
    await day.store.waitForEffects()
    let after = day.model()

    #expect(before.taskItems.map(\.title) == ["Plants", "Vacuum"])
    #expect(before.taskItems.map(\.time) == ["8:00", "8:30"])
    #expect(after.taskItems.map(\.title) == ["Vacuum"])
    #expect(after.taskItems.map(\.time) == ["8:00"])
    #expect(await day.repository.completions().map(\.outcome) == [.done, .done])
}

// MARK: Answers

@MainActor
@Test func notTodayRemovesTheTaskAndLaterMovesItPastTheBlock() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")])
    let before = await day.open()
    #expect(before.taskItems[0].actions.map(\.title) == ["Later", "Not today"])
    #expect(before.taskItems[1].actions.isEmpty)

    before.taskItems[0].actions[0].action()
    await day.store.waitForEffects()
    let later = day.model()
    #expect(later.taskItems.map(\.title) == ["Vacuum", "Plants"])
    #expect(later.taskItems.map(\.time) == ["8:00", "17:00"])

    later.taskItems[0].actions[1].action()
    await day.store.waitForEffects()
    #expect(day.model().taskItems.map(\.title) == ["Plants"])
}

@MainActor
@Test func aTaskWithADeadlineCannotBeRefused() async throws {
    let passport = try Sample.task(1, "Passport", kind: .oneTime, cadence: nil, mustHappenBy: try Sample.november(12))
    let day = try Day(hour: 8, tasks: [passport])

    let model = await day.open()

    #expect(model.taskItems.first?.actions.map(\.title) == ["Later"])
}

@MainActor
@Test func aFailedAnswerShowsAnAlert() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants")])
    let model = await day.open()
    await day.repository.setFailsOnSave(true)

    model.taskItems[0].check.action()
    await day.store.waitForEffects()
    let alert = try #require(day.model().alert)
    alert.dismiss.action()

    #expect(alert.title == "Your answer could not be saved")
    #expect(day.model().alert == nil)
}

// MARK: Wording

@MainActor
@Test func theBriefingNamesTheTasksAndTheMeetingsInBothLanguages() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")], meetings: try morningMeetings())

    let english = await day.open()
    let french = day.model(language: "fr_FR")

    #expect(english.date == "Tuesday 10 November")
    #expect(english.headline == "A light day, Matteo")
    #expect(english.briefing.text == "2 things would be nice today: Plants and Vacuum. You have 3 meetings left today, the next at 10:00.")
    #expect(english.timeline.first?.id == "now")
    #expect(english.taskItems[0].reason == "The first moment that fits.")
    #expect(english.taskItems[0].check.title == "Mark Plants as done")
    #expect(english.briefing.question == "Do you already have something planned for lunch?")
    #expect(french.date == "mardi 10 novembre")
    #expect(french.headline == "Une journée légère, Matteo")
    #expect(french.briefing.text == "2 choses seraient bien aujourd'hui : Plants et Vacuum. Il te reste 3 réunions aujourd'hui, la prochaine à 10:00.")
    #expect(french.meetings == ["10:00 3 réunions à la suite Daily scrum · Weekly sync · 1 de plus · jusqu'à 11:00"])
}

@MainActor
@Test func oneTaskAndAnEmptyDayHaveTheirOwnSentences() async throws {
    let one = try Day(hour: 8, tasks: [try Sample.task(1, "Plants")])
    let none = try Day(hour: 8, tasks: [])

    #expect(await one.open().briefing.text == "One thing would be nice today: Plants.")
    #expect(await none.open().briefing.text == "Nothing needs you today. Enjoy it.")
    #expect(none.model().headline == "A free day, Matteo")
    #expect(none.model().timeline.map(\.id) == ["now"])
}

@MainActor
@Test func aNeglectedTaskSaysHowLongAndComesFirstInTheTiles() async throws {
    let plants = try Sample.task(1, "Plants")
    let vacuum = try Sample.task(2, "Vacuum")
    let gym = try Sample.task(3, "Gym", kind: .goal, cadence: .timesPerWeek(4))
    let day = try Day(hour: 8, tasks: [plants, vacuum, gym])
    try await day.repository.save(try Sample.done(vacuum, day: 2))
    try await day.repository.save(try Sample.done(plants, day: 9))

    let model = await day.open()
    let item = try #require(model.taskItems.first { $0.title == "Vacuum" })

    #expect(item.reason == "8 days since last time")
    #expect(item.isNeglected)
    #expect(model.tiles.map(\.tile.title) == ["Vacuum", "Gym", "Plants"])
    #expect(model.tiles.map(\.tile.detail) == ["8 days since last time", "0 of 4 this week", "In 4 days"])
    #expect(model.tiles.map(\.tile.isNeglected) == [true, true, false])
}

@MainActor
@Test func theWeekShowsScoresUntilTodayAndDotsAfter() async throws {
    let day = try Day(hour: 8, tasks: [])

    let consistency = try #require(await day.open().consistency)

    #expect(consistency.days.map(\.letter) == ["M", "T", "W", "T", "F", "S", "S"])
    #expect(consistency.days.map(\.value) == ["4/5", "rest", "·", "·", "·", "·", "·"])
    #expect(consistency.days.map(\.isToday) == [false, true, false, false, false, false, false])
    #expect(consistency.days.map(\.level) == [0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8])
    #expect(consistency.accessibilityLabel == "Your consistency, Monday 4/5, Tuesday rest")
}
