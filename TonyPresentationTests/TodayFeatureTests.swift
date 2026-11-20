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

    init(
        hour: Int,
        tasks: [TonyTask],
        meetings: [DateInterval] = [],
        languageService: (any LanguageService)? = nil,
        language: String = "en_GB"
    ) throws {
        let clock = TestClock(try Sample.november(10, hour: hour))
        self.clock = clock
        repository = FakeRepository(tasks: tasks)
        let coordinator = PlanCoordinator(
            repository: repository,
            calendarSource: FakeCalendarSource(busyIntervals: meetings),
            calendar: Sample.calendar
        ) { clock.now }
        store = Store(
            state: TodayFeature.State(),
            environment: TodayFeature.Environment(
                coordinator: coordinator,
                briefingWriter: BriefingWriter(service: languageService),
                repository: repository,
                catalog: FakeCatalog(),
                calendar: Sample.calendar,
                locale: Locale(identifier: language),
                suggestionDelay: .zero
            )
        )
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

@Test func appearingAsksForThePlanAndTheName() {
    var state = TodayFeature.State()

    #expect(TodayFeature.reduce(&state, .appeared) == [.plan, .loadName])
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
    #expect(morning.meetings == ["10:00 3 meetings, back to back until 11:00"])
    #expect(morning.briefing.time == "· 8:00")
    #expect(afternoon.taskItems.map(\.time) == ["17:00", "17:30"])
    #expect(afternoon.meetings.isEmpty)
    #expect(afternoon.briefing.time == "· 14:00")
}

@MainActor
@Test func checkingAnItemEarlyFreesItsSlot() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")])
    let before = await day.open()

    before.taskItems[0].check.action.execute()
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

    before.taskItems[0].actions[0].action.execute()
    await day.store.waitForEffects()
    let later = day.model()
    #expect(later.taskItems.map(\.title) == ["Vacuum", "Plants"])
    #expect(later.taskItems.map(\.time) == ["8:00", "17:00"])

    later.taskItems[0].actions[1].action.execute()
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

    model.taskItems[0].check.action.execute()
    await day.store.waitForEffects()
    let alert = try #require(day.model().alert)
    alert.dismiss.action.execute()

    #expect(alert.title == "Your answer could not be saved")
    #expect(day.model().alert == nil)
}

// MARK: The model's wording

@MainActor
@Test func aValidWordingFromTheModelReplacesTheTemplate() async throws {
    let service = FakeLanguageService(briefing: "Start with the plants at 8:00, then the vacuum. Your meetings begin at 10:00.")
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")], meetings: try morningMeetings(), languageService: service)

    let model = await day.open()

    #expect(model.briefing.text == "Start with the plants at 8:00, then the vacuum. Your meetings begin at 10:00.")
    #expect(service.requests.count == 1)
    #expect(service.requests.first?.plan == """
        Tuesday 10 November
        8:00 Plants. The first moment that fits.
        8:30 Vacuum. The first moment that fits.
        Busy from 10:00 to 11:00
        """)
    #expect(service.requests.first?.instructions.contains("Write in English") == true)
}

@MainActor
@Test func aWordingThatNamesATimeOrATaskOutsideThePlanIsNotShown() async throws {
    let plants = try Sample.task(1, "Plants")
    let gym = try Sample.task(2, "Gym", kind: .goal, cadence: .timesPerWeek(1))
    let wrongTime = try Day(hour: 8, tasks: [plants], languageService: FakeLanguageService(briefing: "Water the plants at 9:15."))
    let wrongTask = try Day(hour: 8, tasks: [plants, gym], languageService: FakeLanguageService(briefing: "Plants first, then the gym."))
    try await wrongTask.repository.save(try Sample.done(gym, day: 9))

    #expect(await wrongTime.open().briefing.text == "One thing would be nice today: Plants.")
    #expect(await wrongTask.open().briefing.text == "One thing would be nice today: Plants.")
}

@MainActor
@Test func theModelIsAskedInFrenchAndAgainOnlyWhenThePlanChanges() async throws {
    let service = FakeLanguageService(briefing: "Les Plants d'abord, puis le Vacuum.")
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")], languageService: service, language: "fr_FR")

    let first = await day.open(language: "fr_FR")
    _ = await day.open(language: "fr_FR")
    first.taskItems[0].check.action.execute()
    await day.store.waitForEffects()

    // Opening twice asks once. The new plan is asked twice: the answer still names Plants, now done, so it is retried, then dropped.
    #expect(first.briefing.text == "Les Plants d'abord, puis le Vacuum.")
    #expect(service.requests.count == 3)
    #expect(service.requests.first?.plan == "mardi 10 novembre\n8:00 Plants. Le premier moment qui convient.\n8:30 Vacuum. Le premier moment qui convient.")
    #expect(service.requests.last?.plan == "mardi 10 novembre\n8:00 Vacuum. Le premier moment qui convient.")
    #expect(day.model(language: "fr_FR").briefing.text == "Une chose serait bien aujourd'hui : Vacuum.")
    #expect(service.requests.first?.instructions.contains("Write in French") == true)
}

// MARK: Adding a task

@MainActor
@Test func aTaskAddedFromTodayIsSavedAndPlanned() async throws {
    let day = try Day(hour: 8, tasks: [])
    let empty = await day.open()

    empty.addTask.action.execute()
    let editor = try #require(day.model().editor)
    try #require(editor.composer).composer.text.onChange.execute("Laundry")
    try #require(day.model().editor?.composer).composer.send.action.execute()
    await day.store.waitForEffects()
    let form = try #require(day.model().editor?.form)
    try #require(day.model().editor).save.action.execute()
    await day.store.waitForEffects()
    let model = day.model()

    #expect(empty.addTask.title == "+ Add a task")
    #expect(editor.title == "New task")
    #expect(form.name.text == "Laundry")
    #expect(form.delete == nil)
    #expect(model.editor == nil)
    #expect(await day.repository.savedTasks.map(\.name) == ["Laundry"])
    #expect(await day.repository.savedTasks.first?.steps.map(\.name) == ["Load", "Wash"])
    #expect(model.taskItems.map(\.title) == ["Laundry · Load", "Laundry · Wash"])
}

@MainActor
@Test func cancellingTheFormSavesNothing() async throws {
    let day = try Day(hour: 8, tasks: [])

    await day.open().addTask.action.execute()
    try #require(day.model().editor).cancel.action.execute()
    await day.store.waitForEffects()

    #expect(day.model().editor == nil)
    #expect(await day.repository.savedTasks.isEmpty)
}

@MainActor
@Test func aTaskThatCannotBeSavedShowsAnAlert() async throws {
    let day = try Day(hour: 8, tasks: [])
    await day.open().addTask.action.execute()
    day.store.send(.editor(.sentenceChanged("Passport")))
    day.store.send(.editor(.sentenceSent))
    await day.store.waitForEffects()
    await day.repository.setFailsOnSave(true)

    day.store.send(.editorSaved)
    await day.store.waitForEffects()

    #expect(day.model().alert?.title == "Your tasks could not be saved")
}

// MARK: Wording

@MainActor
@Test func theHeadlineUsesTheNameFromTheYouTab() async throws {
    let day = try Day(hour: 8, tasks: [])
    await day.repository.save(Preference(key: Preference.userNameKey, value: "Matteo", sourceSentence: "", date: day.clock.now))

    let english = await day.open()

    #expect(english.headline == "A free day, Matteo")
    #expect(day.model(language: "fr_FR").headline == "Une journée libre, Matteo")
}

@MainActor
@Test func theBriefingNamesTheTasksAndTheMeetingsInBothLanguages() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")], meetings: try morningMeetings())

    let english = await day.open()
    let french = day.model(language: "fr_FR")

    #expect(english.date == "Tuesday 10 November")
    #expect(english.headline == "A light day")
    #expect(english.briefing.text == "2 things would be nice today: Plants and Vacuum. You have 3 meetings left today, the next at 10:00.")
    #expect(english.timeline.first?.id == "now")
    #expect(english.taskItems[0].reason == "The first moment that fits.")
    #expect(english.taskItems[0].check.title == "Mark Plants as done")
    #expect(french.date == "mardi 10 novembre")
    #expect(french.headline == "Une journée légère")
    #expect(french.briefing.text == "2 choses seraient bien aujourd'hui : Plants et Vacuum. Il te reste 3 réunions aujourd'hui, la prochaine à 10:00.")
    #expect(french.meetings == ["10:00 3 réunions à la suite jusqu'à 11:00"])
}

@MainActor
@Test func oneTaskAndAnEmptyDayHaveTheirOwnSentences() async throws {
    let one = try Day(hour: 8, tasks: [try Sample.task(1, "Plants")])
    let none = try Day(hour: 8, tasks: [])

    #expect(await one.open().briefing.text == "One thing would be nice today: Plants.")
    #expect(await none.open().briefing.text == "Nothing needs you today. Enjoy it.")
    #expect(none.model().headline == "A free day")
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
