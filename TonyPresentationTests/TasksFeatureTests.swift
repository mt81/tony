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
    _ = TasksFeature.reduce(&state, .editor(.nameChanged("Dentist")))

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
@Test func theEditorDataModelFollowsTheEditorState() throws {
    var state = try loadedState()
    _ = TasksFeature.reduce(&state, .addTapped(id: try Sample.identifier(7), stepID: try Sample.identifier(8), now: try Sample.november(10)))

    let (blank, _) = try dataModel(state)
    let blankEditor = try #require(blank.editor)
    #expect(blankEditor.title == "New task")
    #expect(blankEditor.delete == nil)
    #expect(!blankEditor.save.isEnabled)
    #expect(blankEditor.cadence?.count?.title == "Every 7 days")

    _ = TasksFeature.reduce(&state, .editor(.nameChanged("Plants")))
    _ = TasksFeature.reduce(&state, .editor(.cadenceKindChanged(.weekdays)))
    let (named, sent) = try dataModel(state, language: "fr")
    let editor = try #require(named.editor)
    #expect(editor.title == "Nouvelle tâche")
    #expect(editor.cadence?.count == nil)
    #expect(editor.cadence?.weekdays.first?.title == "Lundi")
    #expect(!editor.save.isEnabled)

    editor.cadence?.weekdays.first?.onChange.execute(true)
    editor.name.onChange.execute("Water")
    #expect(sent.actions == [.editor(.weekdayToggled(.monday, isOn: true)), .editor(.nameChanged("Water"))])
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
    let environment = TasksFeature.Environment(repository: repository, catalog: nil, locale: Locale(identifier: "en"))
    let task = try Sample.task(1, "Laundry")

    let action = await TasksFeature.run(.save(task), in: environment)

    #expect(action == .loaded(tasks: [task], completions: []))
}

@MainActor
@Test func aFailedSaveReportsTheFailure() async throws {
    let repository = FakeRepository()
    await repository.setFailsOnSave(true)
    let environment = TasksFeature.Environment(repository: repository, catalog: nil, locale: Locale(identifier: "en"))

    #expect(await TasksFeature.run(.save(try Sample.task(1, "Laundry")), in: environment) == .failed)
}

@MainActor
@Test func theStoreFillsANewTasksStepsFromTheCatalogue() async throws {
    let environment = TasksFeature.Environment(
        repository: FakeRepository(),
        catalog: FakeCatalog(),
        locale: Locale(identifier: "en"),
        suggestionDelay: .zero
    )
    let store = Store<TasksFeature>(state: TasksFeature.State(), environment: environment)

    store.send(.addTapped(id: try Sample.identifier(7), stepID: try Sample.identifier(8), now: try Sample.november(10)))
    store.send(.editor(.nameChanged("Laundry")))
    await store.waitForEffects()

    #expect(store.state.editor?.task.steps.map(\.name) == ["Load", "Wash"])
    #expect(store.dataModel(context: try Sample.context()).editor?.steps.footer == "Suggested by Tony. Change anything that does not fit.")
}

@MainActor
@Test func onlyTheLastNameTypedIsLookedUp() async throws {
    let environment = TasksFeature.Environment(
        repository: FakeRepository(),
        catalog: FakeCatalog(),
        locale: Locale(identifier: "en"),
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

// MARK: Quick add

@MainActor
private func quickAdd(_ sentence: String, language: String = "en", languageService: (any LanguageService)? = nil) async throws -> (Store<TasksFeature>, TaskEditorDataModel) {
    let locale = Locale(identifier: language)
    let environment = TasksFeature.Environment(
        repository: FakeRepository(),
        catalog: FakeCatalog(),
        languageService: languageService,
        locale: locale,
        suggestionDelay: .zero
    )
    let store = Store<TasksFeature>(state: TasksFeature.State(), environment: environment)
    let context = try Sample.context(language: language)

    store.dataModel(context: context).quickAdd.onChange.execute(sentence)
    let submit = try #require(store.dataModel(context: context).quickAdd.onSubmit)
    submit.execute()
    await store.waitForEffects()
    return (store, try #require(store.dataModel(context: context).editor))
}

@MainActor
@Test func aSentenceFillsTheFormInEnglish() async throws {
    let (store, editor) = try await quickAdd("Water the plants every 5 days")

    #expect(editor.title == "New task")
    #expect(editor.name.text == "Water the plants")
    #expect(editor.kind.selectedID == TonyTask.Kind.recurring.rawValue)
    #expect(editor.cadence?.repeats.selectedID == TaskEditor.CadenceKind.afterCompletion.rawValue)
    #expect(editor.cadence?.count?.title == "Every 5 days")
    #expect(editor.save.isEnabled)
    #expect(store.state.quickAdd.isEmpty)
    #expect(store.state.tasks.isEmpty)
}

@MainActor
@Test func aSentenceFillsTheFormInFrench() async throws {
    let (_, editor) = try await quickAdd("Arroser les plantes tous les 5 jours", language: "fr")

    #expect(editor.name.text == "Arroser les plantes")
    #expect(editor.cadence?.repeats.selectedID == TaskEditor.CadenceKind.afterCompletion.rawValue)
    #expect(editor.cadence?.count?.title == "Tous les 5 jours")
}

@MainActor
@Test func aSentenceCanGiveWeekdaysAGoalOrAOneTimeTaskAndItsSteps() async throws {
    let (_, trash) = try await quickAdd("Take out the trash every Tuesday")
    let (_, gym) = try await quickAdd("Go to the gym 3 times a week")
    let (_, passport) = try await quickAdd("Renew my passport")
    let (laundryStore, _) = try await quickAdd("Laundry every week")

    #expect(trash.cadence?.weekdays.filter(\.isOn).map(\.title) == ["Tuesday"])
    #expect(gym.kind.selectedID == TonyTask.Kind.goal.rawValue)
    #expect(gym.cadence?.count?.title == "3 times a week")
    #expect(passport.kind.selectedID == TonyTask.Kind.oneTime.rawValue)
    #expect(passport.cadence == nil)
    #expect(laundryStore.state.editor?.task.steps.map(\.name) == ["Load", "Wash"])
}

@MainActor
@Test func theModelIsAskedOnlyForWhatTheRulesDoNotRead() async throws {
    let service = FakeLanguageService(draft: TaskDraft(name: "Water the plants", cadence: .afterCompletion(days: 3)))

    let (_, byRules) = try await quickAdd("Water the plants every 5 days", languageService: service)
    let (_, byModel) = try await quickAdd("Water the plants every couple of days", languageService: service)

    #expect(byRules.cadence?.count?.title == "Every 5 days")
    #expect(byModel.name.text == "Water the plants")
    #expect(byModel.cadence?.count?.title == "Every 3 days")
    #expect(service.requests.map(\.plan) == ["Water the plants every couple of days"])
    #expect(service.requests.first?.instructions.hasSuffix("The sentence is in English.") == true)
}

@MainActor
@Test func anEmptySentenceOpensNothing() throws {
    var state = TasksFeature.State()
    _ = TasksFeature.reduce(&state, .quickAddChanged("   "))

    #expect(TasksFeature.reduce(&state, .quickAddSubmitted(id: try Sample.identifier(1), stepID: try Sample.identifier(2), now: try Sample.november(10))).isEmpty)
    #expect(state.editor == nil)
}
