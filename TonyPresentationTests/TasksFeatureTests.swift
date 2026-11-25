import Foundation
import Testing
import TonyCore
import TonyUIModels
@testable import TonyPresentation

private func loadedState() throws -> TasksFeature.State {
    var state = TasksFeature.State()
    let tasks = [
        try Sample.task(1, "Laundry"),
        try Sample.task(2, "Gym", kind: .goal, cadence: .timesPerWeek(4)),
        try Sample.task(3, "Plants"),
        try Sample.task(4, "Vacuum"),
    ]
    _ = TasksFeature.reduce(&state, .loaded(tasks: tasks, completions: []))
    return state
}

@MainActor
private func dataModel(_ state: TasksFeature.State, language: String = "en") throws -> (TasksScreenDataModel, SentActions<TasksFeature.Action>) {
    let sent = SentActions<TasksFeature.Action>()
    let model = TasksFeature.dataModel(for: state, context: try Sample.context(language: language), send: sent.send)
    return (model, sent)
}

// MARK: Reducer

@Test func appearingLoadsTheTasks() {
    var state = TasksFeature.State()

    #expect(TasksFeature.reduce(&state, .appeared) == [.load])
}

@Test func movingReordersOnlyThatKindAndSavesTheOrder() throws {
    var state = try loadedState()

    let effects = TasksFeature.reduce(&state, .moved(kind: .recurring, from: [2], to: 0))

    #expect(state.tasks.map(\.name) == ["Vacuum", "Gym", "Laundry", "Plants"])
    #expect(effects == [.reorder([try Sample.identifier(4), try Sample.identifier(1), try Sample.identifier(3)])])
}

@Test func savingANewTaskClosesTheEditorAndSavesIt() throws {
    var state = try loadedState()
    _ = TasksFeature.reduce(&state, .addTapped(id: try Sample.identifier(7), stepID: try Sample.identifier(8), now: try Sample.november(10)))
    _ = TasksFeature.reduce(&state, .editor(.sentenceChanged("Dentist")))
    _ = TasksFeature.reduce(&state, .editor(.sentenceSent))
    _ = TasksFeature.reduce(&state, .editor(.sentenceRead(TaskDraft(name: "Dentist", cadence: nil), stepIDs: [])))

    let effects = TasksFeature.reduce(&state, .editorSaved)

    #expect(state.editor == nil)
    #expect(state.tasks.last?.name == "Dentist")
    #expect(effects.count == 1)
    guard case .save(let saved) = effects.first else {
        Issue.record("expected a save effect, got \(effects)")
        return
    }
    #expect(saved.id == (try Sample.identifier(7)))
}

@Test func anInvalidTaskIsNotSaved() throws {
    var state = try loadedState()
    _ = TasksFeature.reduce(&state, .addTapped(id: try Sample.identifier(7), stepID: try Sample.identifier(8), now: try Sample.november(10)))

    #expect(TasksFeature.reduce(&state, .editorSaved).isEmpty)
    #expect(state.editor != nil)
}

@Test func deletingFromTheEditorRemovesTheTask() throws {
    var state = try loadedState()
    _ = TasksFeature.reduce(&state, .rowTapped(id: try Sample.identifier(3), now: try Sample.november(10)))

    let effects = TasksFeature.reduce(&state, .editorDeleted)

    #expect(effects == [.delete(id: try Sample.identifier(3))])
    #expect(!state.tasks.contains { $0.name == "Plants" })
    #expect(state.editor == nil)
}

@Test func editorEffectsBecomeFeatureEffects() throws {
    var state = TasksFeature.State()
    _ = TasksFeature.reduce(&state, .addTapped(id: try Sample.identifier(7), stepID: try Sample.identifier(8), now: try Sample.november(10)))

    #expect(TasksFeature.reduce(&state, .editor(.nameChanged("Laundry"))) == [.editor(.suggestSteps(forName: "Laundry"))])
}

// MARK: Data model

@MainActor
@Test func sectionsFollowKindsAndSkipEmptyOnes() throws {
    let (model, _) = try dataModel(try loadedState())

    #expect(model.sections.map(\.title) == ["Recurring", "Goals"])
    #expect(model.sections.map(\.hint) == ["Top matters most", "Flexible days"])
    #expect(model.sections[0].rows.map(\.title) == ["Laundry", "Plants", "Vacuum"])
    #expect(model.sections[0].rows[0].accessibilityIdentifier == "task-Laundry")
}

@MainActor
@Test func rowsSayWhenTheTaskIsDueInTheUsersLanguage() throws {
    var state = TasksFeature.State()
    let plants = try Sample.task(1, "Plants")
    let trash = try Sample.task(2, "Trash", cadence: .weekdays([.tuesday]))
    _ = TasksFeature.reduce(&state, .loaded(tasks: [plants, trash], completions: [try Sample.done(plants, day: 9), try Sample.done(trash, day: 10)]))

    let (english, _) = try dataModel(state)
    let (french, _) = try dataModel(state, language: "fr")

    #expect(english.sections[0].rows.map(\.subtitle) == ["Every 5 days after last time", "Every Tuesday"])
    #expect(english.sections[0].rows.map(\.status.title) == ["In 4 days", "In 7 days"])
    #expect(french.sections[0].rows.map(\.subtitle) == ["Tous les 5 jours après la dernière fois", "Chaque mardi"])
    #expect(french.sections[0].rows.map(\.status.title) == ["Dans 4 jours", "Dans 7 jours"])
}

@MainActor
@Test func rowsNameTheIntervalAndWhatItCountsFrom() throws {
    var state = TasksFeature.State()
    let fixedMonthly = Cadence.interval(Cadence.Interval(count: 1, unit: .month), countedFrom: .schedule(from: try Sample.november(1)))
    let tasks = [
        try Sample.task(1, "Sheets", cadence: .every(2, .week)),
        try Sample.task(2, "Kettle", cadence: .every(3, .month)),
        try Sample.task(3, "Boiler", cadence: .every(1, .year)),
        try Sample.task(4, "Rent", cadence: fixedMonthly),
    ]
    _ = TasksFeature.reduce(&state, .loaded(tasks: tasks, completions: []))

    let (english, _) = try dataModel(state)
    let (french, _) = try dataModel(state, language: "fr")

    #expect(english.sections[0].rows.map(\.subtitle) == [
        "Every 2 weeks after last time", "Every 3 months after last time", "Every year after last time", "Every month",
    ])
    #expect(french.sections[0].rows.map(\.subtitle) == [
        "Toutes les 2 semaines après la dernière fois", "Tous les 3 mois après la dernière fois", "Chaque année après la dernière fois", "Tous les mois",
    ])
}

@MainActor
@Test func aNeglectedTaskShowsDueInTheWarningStyle() throws {
    var state = TasksFeature.State()
    let plants = try Sample.task(1, "Plants")
    _ = TasksFeature.reduce(&state, .loaded(tasks: [plants], completions: [try Sample.done(plants, day: 2)]))

    let row = try #require(try dataModel(state).0.sections.first?.rows.first)

    #expect(row.status == ChipDataModel(title: "Due", style: .warning))
    #expect(row.isNeglected)
}

@MainActor
@Test func tappingSendsTheMatchingActions() throws {
    let (model, sent) = try dataModel(try loadedState())
    let row = model.sections[0].rows[1]

    model.onAppear.execute()
    row.delete.action.execute()
    model.sections[0].move.execute(Move(source: [0], destination: 2))

    #expect(sent.actions == [
        .appeared,
        .deleteTapped(id: row.id),
        .moved(kind: .recurring, from: [0], to: 2),
    ])
}

@MainActor
@Test func aNewTaskOpensOnTheComposer() throws {
    var state = try loadedState()
    _ = TasksFeature.reduce(&state, .addTapped(id: try Sample.identifier(7), stepID: try Sample.identifier(8), now: try Sample.november(10)))

    let (blank, _) = try dataModel(state)
    let blankEditor = try #require(blank.editor)
    let blankComposer = try #require(blankEditor.composer)
    #expect(blankEditor.title == "New task")
    #expect(blankEditor.form == nil)
    #expect(!blankEditor.save.isEnabled)
    #expect(blankComposer.prompt == "Describe your task")
    #expect(!blankComposer.composer.send.isEnabled)

    _ = TasksFeature.reduce(&state, .editor(.sentenceChanged("Arroser les plantes")))
    let (typed, sent) = try dataModel(state, language: "fr")
    let editor = try #require(typed.editor)
    let composer = try #require(editor.composer)
    #expect(editor.title == "Nouvelle tâche")
    #expect(composer.prompt == "Décrivez votre tâche")
    #expect(composer.composer.send.isEnabled)

    composer.composer.send.action.execute()
    #expect(sent.actions == [.editor(.sentenceSent)])

    _ = TasksFeature.reduce(&state, .editor(.sentenceSent))
    let reading = try #require(try dataModel(state).0.editor?.composer)
    #expect(reading.composer.isSending)
    #expect(!reading.composer.send.isEnabled)
}

@MainActor
@Test func theFormShowsEveryValueInTheUsersLanguage() throws {
    var state = try loadedState()
    _ = TasksFeature.reduce(&state, .rowTapped(id: try Sample.identifier(3), now: try Sample.november(10)))

    let english = try #require(try dataModel(state).0.editor?.form)
    let french = try #require(try dataModel(state, language: "fr").0.editor?.form)

    #expect(try dataModel(state).0.editor?.title == "Edit task")
    #expect(english.name.text == "Plants")
    #expect(english.delete != nil)
    #expect(english.repeats.row.value == "Every 5 days")
    #expect(english.countedFrom?.row.value == "Last time done")
    #expect(english.deadline.row.value == "None")
    #expect(english.location.row.value == "Anywhere")
    #expect(english.timeOfDay.row.value == "Any time")
    #expect(english.weather.row.value == "Any weather")
    #expect(english.subtasks.subtasks.map(\.duration.selectedID) == ["30"])
    #expect(french.repeats.row.value == "Tous les 5 jours")
    #expect(french.countedFrom?.row.value == "La dernière fois")
    #expect(french.timeOfDay.row.value == "N’importe quand")
}

@MainActor
@Test func theWeatherRowShowsWhatTheTaskNeedsInTheUsersLanguage() throws {
    var state = try loadedState()
    _ = TasksFeature.reduce(&state, .rowTapped(id: try Sample.identifier(3), now: try Sample.november(10)))
    _ = TasksFeature.reduce(&state, .editor(.weatherToggled(.fair, isOn: true)))
    _ = TasksFeature.reduce(&state, .editor(.weatherToggled(.clear, isOn: true)))
    _ = TasksFeature.reduce(&state, .editor(.weatherToggled(.partlyCloudy, isOn: true)))

    let english = try #require(try dataModel(state).0.editor?.form?.weather)
    let french = try #require(try dataModel(state, language: "fr").0.editor?.form?.weather)

    #expect(english.row.value == "Clear, fair, or partly cloudy")
    #expect(english.any.isOn == false)
    #expect(english.conditions.map(\.systemImage) == ["sun.max", "sun.haze", "cloud.sun", "cloud", "cloud.fog", "cloud.rain", "cloud.sleet", "cloud.snow", "cloud.bolt"])
    #expect(english.conditions.filter(\.isOn).map(\.title) == ["Clear", "Fair", "Partly cloudy"])
    #expect(french.row.value == "Dégagé, beau temps ou partiellement nuageux")
    #expect(french.conditions.map(\.title) == ["Dégagé", "Beau temps", "Partiellement nuageux", "Nuageux", "Brouillard", "Pluie", "Neige fondue", "Neige", "Orage"])
    #expect(french.footer == "Tony ne le planifie que les jours avec ce temps. Sans prévision, n’importe quel jour convient.")
}

@MainActor
@Test func theFormSendsWhatTheUserPicks() throws {
    var state = try loadedState()
    _ = TasksFeature.reduce(&state, .rowTapped(id: try Sample.identifier(3), now: try Sample.november(10)))
    let (model, sent) = try dataModel(state)
    let form = try #require(model.editor?.form)

    form.repeats.choices.onSelect.execute(TaskEditor.Repeats.everyMonth.rawValue)
    form.countedFrom?.choices.onSelect.execute("fixed")
    form.location.choices.onSelect.execute("home")
    form.timeOfDay.items[1].onChange.execute(true)
    form.weather.any.onChange.execute(true)
    form.weather.conditions[1].onChange.execute(true)
    form.name.onChange.execute("Water")

    #expect(sent.actions == [
        .editor(.repeatsChanged(.everyMonth)),
        .editor(.countedFromChanged(isFixed: true)),
        .editor(.locationChanged(.home)),
        .editor(.windowToggled(.morning, isOn: true)),
        .editor(.weatherToggled(nil, isOn: true)),
        .editor(.weatherToggled(.fair, isOn: true)),
        .editor(.nameChanged("Water")),
    ])
}

@MainActor
@Test func customShowsItsFrequencyAndWeekdays() throws {
    var state = try loadedState()
    _ = TasksFeature.reduce(&state, .rowTapped(id: try Sample.identifier(3), now: try Sample.november(10)))
    _ = TasksFeature.reduce(&state, .editor(.repeatsChanged(.custom)))
    _ = TasksFeature.reduce(&state, .editor(.customUnitChanged(.week)))

    let weekly = try #require(try dataModel(state, language: "fr").0.editor?.form?.repeats.custom)
    #expect(weekly.frequency.selectedID == "week")
    #expect(weekly.count?.title == "Toutes les 5 semaines")
    #expect(weekly.weekdays.first?.title == "Lundi")

    _ = TasksFeature.reduce(&state, .editor(.weekdayToggled(.monday, isOn: true)))
    let onMondays = try #require(try dataModel(state).0.editor?.form?.repeats)
    #expect(onMondays.custom?.count == nil)
    #expect(onMondays.row.value == "Every Monday")
    #expect(try dataModel(state).0.editor?.form?.countedFrom == nil)
}

@MainActor
@Test func aFailureShowsAnAlertThatCanBeDismissed() throws {
    var state = TasksFeature.State()
    _ = TasksFeature.reduce(&state, .failed)

    let (model, sent) = try dataModel(state)
    let alert = try #require(model.alert)
    alert.dismiss.action.execute()
    _ = TasksFeature.reduce(&state, sent.actions[0])

    #expect(alert.title == "Your tasks could not be saved")
    #expect(try dataModel(state).0.alert == nil)
}

// MARK: Effects

@MainActor
@Test func savingStoresTheTaskAndReloads() async throws {
    let repository = FakeRepository()
    let environment = TasksFeature.Environment(repository: repository, catalog: nil, locale: Locale(identifier: "en"), calendar: Sample.calendar)
    let task = try Sample.task(1, "Laundry")

    let action = await TasksFeature.run(.save(task), in: environment)

    #expect(action == .loaded(tasks: [task], completions: []))
}

@MainActor
@Test func aFailedSaveReportsTheFailure() async throws {
    let repository = FakeRepository()
    await repository.setFailsOnSave(true)
    let environment = TasksFeature.Environment(repository: repository, catalog: nil, locale: Locale(identifier: "en"), calendar: Sample.calendar)

    #expect(await TasksFeature.run(.save(try Sample.task(1, "Laundry")), in: environment) == .failed)
}

@MainActor
@Test func theStoreFillsANewTasksStepsFromTheCatalogue() async throws {
    let environment = TasksFeature.Environment(
        repository: FakeRepository(),
        catalog: FakeCatalog(),
        locale: Locale(identifier: "en"),
        calendar: Sample.calendar,
        suggestionDelay: .zero
    )
    let store = Store<TasksFeature>(state: TasksFeature.State(), environment: environment)

    store.send(.addTapped(id: try Sample.identifier(7), stepID: try Sample.identifier(8), now: try Sample.november(10)))
    store.send(.editor(.nameChanged("Laundry")))
    await store.waitForEffects()

    #expect(store.state.editor?.task.steps.map(\.name) == ["Load", "Wash"])
}

@MainActor
@Test func onlyTheLastNameTypedIsLookedUp() async throws {
    let environment = TasksFeature.Environment(
        repository: FakeRepository(),
        catalog: FakeCatalog(),
        locale: Locale(identifier: "en"),
        calendar: Sample.calendar,
        suggestionDelay: .milliseconds(50)
    )
    let store = Store<TasksFeature>(state: TasksFeature.State(), environment: environment)
    store.send(.addTapped(id: try Sample.identifier(7), stepID: try Sample.identifier(8), now: try Sample.november(10)))

    store.send(.editor(.nameChanged("Laundry")))
    store.send(.editor(.nameChanged("Passport")))
    await store.waitForEffects()

    #expect(store.state.editor?.task.steps.map(\.name) == [""])
    #expect(store.state.editor?.suggestedSteps == nil)
}

// MARK: Composing

/// Types the sentence in a new task's composer and sends it, then returns the form it fills.
@MainActor
private func compose(_ sentence: String, language: String = "en", languageService: (any LanguageService)? = nil) async throws -> (Store<TasksFeature>, TaskFormDataModel) {
    let locale = Locale(identifier: language)
    let environment = TasksFeature.Environment(
        repository: FakeRepository(),
        catalog: FakeCatalog(),
        languageService: languageService,
        locale: locale,
        calendar: Sample.calendar,
        suggestionDelay: .zero
    )
    let store = Store<TasksFeature>(state: TasksFeature.State(), environment: environment)
    let context = try Sample.context(language: language)
    store.send(.addTapped(id: try Sample.identifier(7), stepID: try Sample.identifier(8), now: try Sample.november(10)))

    try #require(store.dataModel(context: context).editor?.composer).composer.text.onChange.execute(sentence)
    try #require(store.dataModel(context: context).editor?.composer).composer.send.action.execute()
    await store.waitForEffects()
    return (store, try #require(store.dataModel(context: context).editor?.form))
}

@MainActor
@Test func aSentenceFillsTheFormInEnglish() async throws {
    let (store, form) = try await compose("Water the plants every 5 days")

    #expect(form.name.text == "Water the plants")
    #expect(form.repeats.row.value == "Every 5 days")
    #expect(form.repeats.choices.selectedID == TaskEditor.Repeats.custom.rawValue)
    #expect(form.countedFrom?.row.value == "Last time done")
    #expect(store.dataModel(context: try Sample.context()).editor?.save.isEnabled == true)
    #expect(store.state.tasks.isEmpty)
}

@MainActor
@Test func aSentenceFillsTheFormInFrench() async throws {
    let (_, form) = try await compose("Arroser les plantes tous les 5 jours", language: "fr")

    #expect(form.name.text == "Arroser les plantes")
    #expect(form.repeats.row.value == "Tous les 5 jours")
}

@MainActor
@Test func aSentenceCanGiveWeekdaysAGoalOrAOneTimeTaskAndItsSteps() async throws {
    let (_, trash) = try await compose("Take out the trash every Tuesday")
    let (gymStore, gym) = try await compose("Go to the gym 3 times a week")
    let (passportStore, passport) = try await compose("Renew my passport")
    let (laundryStore, laundry) = try await compose("Laundry every two weeks")

    #expect(trash.repeats.row.value == "Every Tuesday")
    #expect(gym.repeats.row.value == "3 times a week")
    #expect(gymStore.state.editor?.editedTask.kind == .goal)
    #expect(passport.repeats.row.value == "Never")
    #expect(passport.countedFrom == nil)
    #expect(passportStore.state.editor?.editedTask.kind == .oneTime)
    #expect(laundry.repeats.choices.selectedID == TaskEditor.Repeats.everyTwoWeeks.rawValue)
    #expect(laundryStore.state.editor?.task.steps.map(\.name) == ["Load", "Wash"])
}

@MainActor
@Test func theModelFillsWhatTheRulesDoNotRead() async throws {
    let reading = TaskReading(
        name: "Water the plants",
        icon: "🪴",
        cadence: .every(3, .day),
        requirements: Requirements(location: .home, windows: [.morning])
    )
    let service = FakeLanguageService(reading: reading)

    let (_, byRules) = try await compose("Water the plants every 5 days", languageService: service)
    let (_, byModel) = try await compose("Water the plants every couple of days", languageService: service)

    #expect(byRules.repeats.row.value == "Every 5 days")
    #expect(byRules.icon.text == "🪴")
    #expect(byRules.location.row.value == "At home")
    #expect(byRules.timeOfDay.row.value == "Morning")
    #expect(byModel.repeats.row.value == "Every 3 days")
    #expect(service.requests.map(\.plan) == ["Water the plants every 5 days", "Water the plants every couple of days"])
    #expect(service.requests.first?.instructions.contains("The sentence is in English. Today is Tuesday, November 10, 2026.") == true)
}
