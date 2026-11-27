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
    let permissions: PermissionStore
    let store: TodayStore

    init(
        hour: Int,
        tasks: [TonyTask],
        meetings: [DateInterval] = [],
        calendarAccess: FakePermissionProvider = FakePermissionProvider(status: .granted),
        languageService: (any LanguageService)? = nil,
        language: String = "en_GB"
    ) throws {
        let clock = TestClock(try Sample.november(10, hour: hour))
        self.clock = clock
        repository = FakeRepository(tasks: tasks)
        let coordinator = PlanCoordinator(
            repository: repository,
            calendarSource: FakeCalendarSource(busyIntervals: meetings),
            weatherSource: FakeWeatherSource(),
            calendar: Sample.calendar
        ) { clock.now }
        let permissions = PermissionStore.fake(calendarAccess)
        self.permissions = permissions
        store = TodayStore(
            coordinator: coordinator,
            permissions: permissions,
            briefingWriter: BriefingWriter(service: languageService),
            repository: repository,
            catalog: FakeCatalog(),
            calendar: Sample.calendar,
            locale: Locale(identifier: language),
            suggestionDelay: .zero
        )
    }

    func open(language: String = "en_GB") async -> TodayViewModel {
        let viewModel = viewModel(language: language)
        await viewModel.load()
        return viewModel
    }

    func viewModel(language: String = "en_GB") -> TodayViewModel {
        TodayViewModel(store: store, context: PresentationContext(now: clock.now, calendar: Sample.calendar, locale: Locale(identifier: language)))
    }

    /// The plan's items, in order.
    func items() throws -> [DayPlan.Item] {
        try #require(store.state.planned).plan.items
    }

    /// Waits until the task form's lookups are over, including the ones they lead to.
    func settleEditor() async {
        while let work = store.editorWork {
            await work.value
            if store.editorWork == work {
                return
            }
        }
    }
}

extension TodayViewModel {
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

// MARK: Store

@MainActor
@Test func loadingReadsThePlanTheNameAndCalendarAccess() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants")], calendarAccess: FakePermissionProvider(status: .denied))
    await day.repository.save(Preference(key: Preference.userNameKey, value: "Matteo", sourceSentence: "", date: day.clock.now))

    await day.store.load()

    #expect(try day.items().count == 1)
    #expect(day.store.state.userName == "Matteo")
    #expect(day.store.state.calendarAccess == .denied)
}

@MainActor
@Test func aMissingPlanKeepsTheOneOnScreen() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants")])
    _ = await day.open()
    let planned = day.store.state.planned

    await day.store.show(nil)

    #expect(planned != nil)
    #expect(day.store.state.planned == planned)
}

// MARK: Done when

@MainActor
@Test func openingAtEightAndAtTwoShowsDifferentPlans() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")], meetings: try morningMeetings())

    let morning = await day.open()
    let morningItems = morning.taskItems
    let morningMeetings = morning.meetings
    day.clock.set(try Sample.november(10, hour: 14))
    let afternoon = await day.open()

    #expect(morningItems.map(\.time) == ["8:00", "8:30"])
    #expect(morningItems.map(\.now) == ["8:00 · a good moment to start", nil])
    #expect(morningMeetings == ["10:00 3 meetings, back to back until 11:00"])
    #expect(afternoon.taskItems.map(\.time) == ["17:00", "17:30"])
    #expect(afternoon.taskItems.map(\.now) == [nil, nil])
    #expect(afternoon.timeline.first?.item == .now(text: "Now"))
    #expect(afternoon.meetings.isEmpty)
}

@MainActor
@Test func checkingAnItemEarlyFreesItsSlot() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")])
    let viewModel = await day.open()
    let before = viewModel.taskItems
    let doneBefore = viewModel.timeline.first?.item

    await day.store.check(try day.items()[0])

    #expect(before.map(\.title) == ["Plants", "Vacuum"])
    #expect(before.map(\.time) == ["8:00", "8:30"])
    #expect(viewModel.taskItems.map(\.title) == ["Vacuum"])
    #expect(viewModel.taskItems.map(\.time) == ["8:00"])
    #expect(doneBefore != .done(text: "Good job, today you already did Plants."))
    #expect(viewModel.timeline.first?.item == .done(text: "Good job, today you already did Plants."))
    #expect(day.viewModel(language: "fr_FR").timeline.first?.item == .done(text: "Bravo, aujourd'hui tu as déjà fait Plants."))
    #expect(await day.repository.completions().map(\.outcome) == [.done, .done])
}

@MainActor
@Test func theCheckButtonChecksItsItem() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants")])
    let viewModel = await day.open()

    viewModel.taskItems[0].check.action.execute()
    // The button starts the store's work without waiting for it; sleeping lets that work run.
    while await day.repository.completions().count < 2 {
        try await Task.sleep(for: .milliseconds(10))
    }

    #expect(await day.repository.completions().map(\.outcome) == [.done, .done])
}

@MainActor
@Test func tilesTakeTheAreaColoursInTheOrderOfTheTasks() async throws {
    let tasks = try (1...7).map { try Sample.task($0, "Task \($0)") }
    let day = try Day(hour: 8, tasks: tasks)

    let viewModel = await day.open()

    #expect(viewModel.tiles.map(\.tile.colour) == [.yellow, .green, .blue, .orange, .teal, .indigo])
}

// MARK: Answers

@MainActor
@Test func notTodayRemovesTheTaskAndLaterMovesItPastTheBlock() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")])
    let viewModel = await day.open()
    #expect(viewModel.taskItems[0].actions.map(\.title) == ["Later", "Not today"])
    #expect(viewModel.taskItems[1].actions.isEmpty)

    await day.store.postpone(try day.items()[0])
    #expect(viewModel.taskItems.map(\.title) == ["Vacuum", "Plants"])
    #expect(viewModel.taskItems.map(\.time) == ["8:00", "17:00"])

    await day.store.refuse(try day.items()[0])
    #expect(viewModel.taskItems.map(\.title) == ["Plants"])
}

@MainActor
@Test func aTaskWithADeadlineCannotBeRefused() async throws {
    let passport = try Sample.task(1, "Passport", kind: .oneTime, cadence: nil, mustHappenBy: try Sample.november(12))
    let day = try Day(hour: 8, tasks: [passport])

    let viewModel = await day.open()

    #expect(viewModel.taskItems.first?.actions.map(\.title) == ["Later"])
}

@MainActor
@Test func aFailedAnswerShowsAnAlert() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants")])
    let viewModel = await day.open()
    await day.repository.setFailsOnSave(true)

    await day.store.check(try day.items()[0])
    let alert = try #require(viewModel.alert)
    alert.dismiss.action.execute()

    #expect(alert.title == "Your answer could not be saved")
    #expect(viewModel.alert == nil)
}

// MARK: The model's wording

@MainActor
@Test func aValidWordingFromTheModelReplacesTheTemplate() async throws {
    let service = FakeLanguageService(briefing: "Start with the plants at 8:00, then the vacuum. Your meetings begin at 10:00.")
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")], meetings: try morningMeetings(), languageService: service)

    let viewModel = await day.open()

    #expect(viewModel.briefing == "Start with the plants at 8:00, then the vacuum. Your meetings begin at 10:00.")
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

    #expect(await wrongTime.open().briefing == "One thing would be nice today: Plants.")
    #expect(await wrongTask.open().briefing == "One thing would be nice today: Plants.")
}

@MainActor
@Test func theModelIsAskedInFrenchAndAgainOnlyWhenThePlanChanges() async throws {
    let service = FakeLanguageService(briefing: "Les Plants d'abord, puis le Vacuum.")
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")], languageService: service, language: "fr_FR")

    let first = await day.open(language: "fr_FR").briefing
    _ = await day.open(language: "fr_FR")
    await day.store.check(try day.items()[0])

    // Opening twice asks once. The new plan is asked twice: the answer still names Plants, now done, so it is retried, then dropped.
    #expect(first == "Les Plants d'abord, puis le Vacuum.")
    #expect(service.requests.count == 3)
    #expect(service.requests.first?.plan == "mardi 10 novembre\n8:00 Plants. Le premier moment qui convient.\n8:30 Vacuum. Le premier moment qui convient.")
    #expect(service.requests.last?.plan == "mardi 10 novembre\n8:00 Vacuum. Le premier moment qui convient.")
    #expect(day.viewModel(language: "fr_FR").briefing == "Une chose serait bien aujourd'hui : Vacuum.")
    #expect(service.requests.first?.instructions.contains("Write in French") == true)
}

// MARK: Calendar

@MainActor
@Test func withoutCalendarAccessTodayOffersToPlanAroundEvents() async throws {
    let undecided = try Day(hour: 8, tasks: [], calendarAccess: FakePermissionProvider(status: .notDetermined))
    let refused = try Day(hour: 8, tasks: [], calendarAccess: FakePermissionProvider(status: .denied))
    let granted = try Day(hour: 8, tasks: [])

    let card = try #require(await undecided.open().calendar)
    let french = undecided.viewModel(language: "fr").calendar

    #expect(card.allow?.title == "Plan around my events")
    #expect(card.text == "Tony doesn’t see your calendar yet, so he can’t plan around your meetings.")
    #expect(french?.allow?.title == "Planifier autour de mes événements")
    #expect(await refused.open().calendar?.allow != nil)
    #expect(await granted.open().calendar == nil)
}

@MainActor
@Test func planAroundMyEventsAsksThroughThePermissionSheetAndTheCardGoesOnceGranted() async throws {
    let calendar = FakePermissionProvider(status: .notDetermined, answer: .granted)
    let day = try Day(hour: 8, tasks: [], calendarAccess: calendar)
    let viewModel = await day.open()

    #expect(viewModel.calendar?.allow != nil)
    let asking = Task { await day.store.planAroundEvents() }
    await day.permissions.untilAsking()
    let asked = await calendar.requestCount
    await day.permissions.grant()
    await asking.value

    #expect(asked == 0)
    #expect(await calendar.requestCount == 1)
    #expect(viewModel.calendar == nil)
}

@MainActor
@Test func closingThePermissionSheetKeepsTheCard() async throws {
    let calendar = FakePermissionProvider(status: .notDetermined)
    let day = try Day(hour: 8, tasks: [], calendarAccess: calendar)
    let viewModel = await day.open()

    let asking = Task { await day.store.planAroundEvents() }
    await day.permissions.untilAsking()
    day.permissions.notNow()
    await asking.value

    #expect(await calendar.requestCount == 0)
    #expect(viewModel.calendar != nil)
}

// MARK: Adding a task

@MainActor
@Test func aTaskAddedFromTodayIsSavedAndPlanned() async throws {
    let day = try Day(hour: 8, tasks: [])
    let viewModel = await day.open()

    day.store.startAdding(id: UUID(), stepID: UUID(), now: day.clock.now)
    let editor = try #require(viewModel.editor)
    try #require(editor.composer).composer.text.onChange.execute("Laundry")
    try #require(viewModel.editor?.composer).composer.send.action.execute()
    await day.settleEditor()
    let form = try #require(viewModel.editor?.form)
    await day.store.saveEditor()

    #expect(editor.title == "New task")
    #expect(form.name.text == "Laundry")
    #expect(form.delete == nil)
    #expect(viewModel.editor == nil)
    #expect(await day.repository.savedTasks.map(\.name) == ["Laundry"])
    #expect(await day.repository.savedTasks.first?.steps.map(\.name) == ["Load", "Wash"])
    #expect(viewModel.taskItems.map(\.title) == ["Laundry · Load", "Laundry · Wash"])
}

@MainActor
@Test func cancellingTheFormSavesNothing() async throws {
    let day = try Day(hour: 8, tasks: [])
    let viewModel = await day.open()

    day.store.startAdding(id: UUID(), stepID: UUID(), now: day.clock.now)
    try #require(viewModel.editor).cancel.action.execute()

    #expect(viewModel.editor == nil)
    #expect(await day.repository.savedTasks.isEmpty)
}

@MainActor
@Test func aTaskThatCannotBeSavedShowsAnAlert() async throws {
    let day = try Day(hour: 8, tasks: [])
    let viewModel = await day.open()
    day.store.startAdding(id: UUID(), stepID: UUID(), now: day.clock.now)
    day.store.edit(.sentenceChanged("Passport"))
    day.store.edit(.sentenceSent)
    await day.settleEditor()
    await day.repository.setFailsOnSave(true)

    await day.store.saveEditor()

    #expect(viewModel.alert?.title == "Your tasks could not be saved")
}

// MARK: Wording

@MainActor
@Test func theHeadlineUsesTheNameFromTheYouTab() async throws {
    let day = try Day(hour: 8, tasks: [])
    await day.repository.save(Preference(key: Preference.userNameKey, value: "Matteo", sourceSentence: "", date: day.clock.now))

    let english = await day.open()

    #expect(String(english.headline.characters) == "A free day, Matteo")
    #expect(String(day.viewModel(language: "fr_FR").headline.characters) == "Une journée libre, Matteo")
}

@MainActor
@Test func theHeadlineEmphasisesTheKindOfDayInBothLanguages() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants")])
    await day.repository.save(Preference(key: Preference.userNameKey, value: "Matteo", sourceSentence: "", date: day.clock.now))

    let english = await day.open().headline
    let french = day.viewModel(language: "fr_FR").headline

    func emphasised(_ headline: AttributedString) -> [String] {
        headline.runs.filter { $0.inlinePresentationIntent == .emphasized }.map { String(headline[$0.range].characters) }
    }
    #expect(emphasised(english) == ["light"])
    #expect(emphasised(french) == ["légère"])
}

@MainActor
@Test func theBriefingNamesTheTasksAndTheMeetingsInBothLanguages() async throws {
    let day = try Day(hour: 8, tasks: [try Sample.task(1, "Plants"), try Sample.task(2, "Vacuum")], meetings: try morningMeetings())

    let english = await day.open()
    let french = day.viewModel(language: "fr_FR")

    #expect(english.date == "Tuesday 10 November")
    #expect(String(english.headline.characters) == "A light day")
    #expect(english.briefing == "2 things would be nice today: Plants and Vacuum. You have 3 meetings left today, the next at 10:00.")
    #expect(!english.timeline.contains { $0.id == "now" })
    #expect(english.taskItems[0].now == "8:00 · a good moment to start")
    #expect(english.taskItems[0].reason == "The first moment that fits.")
    #expect(english.taskItems[0].check.title == "Mark Plants as done")
    #expect(french.date == "mardi 10 novembre")
    #expect(String(french.headline.characters) == "Une journée légère")
    #expect(french.briefing == "2 choses seraient bien aujourd'hui : Plants et Vacuum. Il te reste 3 réunions aujourd'hui, la prochaine à 10:00.")
    #expect(french.meetings == ["10:00 3 réunions à la suite jusqu'à 11:00"])
    #expect(french.taskItems[0].now == "8:00 · un bon moment pour commencer")
}

@MainActor
@Test func oneTaskAndAnEmptyDayHaveTheirOwnSentences() async throws {
    let one = try Day(hour: 8, tasks: [try Sample.task(1, "Plants")])
    let none = try Day(hour: 8, tasks: [])

    #expect(await one.open().briefing == "One thing would be nice today: Plants.")
    #expect(await none.open().briefing == "Nothing needs you today. Enjoy it.")
    #expect(String(none.viewModel().headline.characters) == "A free day")
    #expect(none.viewModel().timeline.map(\.id) == ["now"])
}

@MainActor
@Test func aNeglectedTaskSaysHowLongAndComesFirstInTheTiles() async throws {
    let plants = try Sample.task(1, "Plants")
    let vacuum = try Sample.task(2, "Vacuum")
    let gym = try Sample.task(3, "Gym", kind: .goal, cadence: .timesPerWeek(4))
    let day = try Day(hour: 8, tasks: [plants, vacuum, gym])
    try await day.repository.save(try Sample.done(vacuum, day: 2))
    try await day.repository.save(try Sample.done(plants, day: 9))

    let viewModel = await day.open()
    let item = try #require(viewModel.taskItems.first { $0.title == "Vacuum" })

    #expect(item.reason == "8 days since last time")
    #expect(item.isNeglected)
    #expect(viewModel.tiles.map(\.tile.title) == ["Vacuum", "Gym", "Plants"])
    #expect(viewModel.tiles.map(\.tile.detail) == ["8 days since last time", "0 of 4 this week", "In 4 days"])
    #expect(viewModel.tiles.map(\.tile.isNeglected) == [true, true, false])
}
