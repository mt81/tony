import Foundation
import Testing
import TonyCore
import TonyUIModels
@testable import TonyPresentation

@MainActor
private struct You {
    let repository = FakeRepository(tasks: [])
    let store: Store<YouFeature>

    init(calendarSource: any CalendarSource = FakeCalendarSource()) throws {
        let now = try Sample.november(10)
        let coordinator = PlanCoordinator(repository: repository, calendarSource: calendarSource, calendar: Sample.calendar) { now }
        store = Store(
            state: YouFeature.State(),
            environment: YouFeature.Environment(repository: repository, calendarSource: calendarSource, coordinator: coordinator)
        )
    }

    func open(language: String = "en_GB") async throws -> YouScreenDataModel {
        store.send(.appeared)
        await store.waitForEffects()
        return try model(language: language)
    }

    func model(language: String = "en_GB") throws -> YouScreenDataModel {
        store.dataModel(context: try Sample.context(language: language))
    }
}

private func time(_ hour: Int, _ minute: Int = 0) throws -> Date {
    try #require(Sample.calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: hour, minute: minute)))
}

// MARK: Reducer

@Test func changingADayMovesItBetweenHomeOfficeAndOff() {
    var state = YouFeature.State()
    _ = YouFeature.reduce(&state, .editTapped)

    _ = YouFeature.reduce(&state, .dayChanged(.tuesday, .office))
    _ = YouFeature.reduce(&state, .dayChanged(.friday, .off))
    _ = YouFeature.reduce(&state, .dayChanged(.saturday, .home))

    #expect(state.editor?.routine.homeDays == [.monday, .wednesday, .thursday, .saturday])
    #expect(state.editor?.routine.officeDays == [.tuesday])
    #expect(state.routine == .standard)
}

@Test func workThatEndsBeforeItStartsIsNotSaved() throws {
    var state = YouFeature.State()
    _ = YouFeature.reduce(&state, .editTapped)
    _ = YouFeature.reduce(&state, .timeChanged(.workEnd, DateComponents(hour: 8, minute: 30)))

    #expect(YouFeature.reduce(&state, .editorSaved(now: try Sample.november(10))).isEmpty)
    #expect(state.editor != nil)
}

// MARK: Data model

@MainActor
@Test func aNewUserSeesTheStandardRoutineInBothLanguages() async throws {
    let you = try You()

    let english = try await you.open()
    let french = try you.model(language: "fr_FR")

    #expect(english.name == "You")
    #expect(english.initial == nil)
    #expect(english.routine.lines == ["Home on Mon, Tue, Wed, Thu, Fri", "Workday 9:00 to 17:00", "Up around 7:00 · bed around 23:00"])
    #expect(french.name == "Toi")
    #expect(french.routine.lines == ["Maison : lun., mar., mer., jeu., ven.", "Travail de 9:00 à 17:00", "Lever vers 7:00 · coucher vers 23:00"])
}

@MainActor
@Test func savingTheFormStoresTheNameAndTheRoutine() async throws {
    let you = try You()
    try await you.open().routine.edit.action()
    let editor = try #require(try you.model().editor)

    editor.name.onChange(" Matteo ")
    editor.days[1].picker.onSelect(YouFeature.DayKind.office.rawValue)
    editor.days[5].picker.onSelect(YouFeature.DayKind.home.rawValue)
    editor.workEnd.onChange(try time(17, 30))
    editor.bedtime.onChange(try time(22, 15))
    try #require(try you.model().editor).save.action()
    await you.store.waitForEffects()
    let model = try you.model()
    let stored = try #require(await you.repository.routine())

    #expect(editor.days.map(\.picker.title) == ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
    #expect(editor.days.map(\.picker.selectedID) == ["home", "home", "home", "home", "home", "off", "off"])
    #expect(model.editor == nil)
    #expect(model.name == "Matteo")
    #expect(model.initial == "M")
    #expect(model.routine.lines == ["Home on Mon, Wed, Thu, Fri, Sat · Office on Tue", "Workday 9:00 to 17:30", "Up around 7:00 · bed around 22:15"])
    #expect(stored.officeDays == [.tuesday])
    #expect(stored.workEnd == DateComponents(hour: 17, minute: 30))
    #expect(await you.repository.preferences().map(\.value) == ["Matteo"])
}

@MainActor
@Test func invalidWorkHoursDisableSavingAndSayWhy() async throws {
    let you = try You()
    try await you.open().routine.edit.action()

    try #require(try you.model().editor).workStart.onChange(try time(18))
    let editor = try #require(try you.model().editor)

    #expect(!editor.save.isEnabled)
    #expect(editor.workFooter == "Work has to end after it starts.")
}

@MainActor
@Test func aRoutineThatCannotBeSavedShowsAnAlert() async throws {
    let you = try You()
    try await you.open().routine.edit.action()
    await you.repository.setFailsOnSave(true)

    try #require(try you.model().editor).save.action()
    await you.store.waitForEffects()
    let alert = try #require(try you.model().alert)
    alert.dismiss.action()

    #expect(alert.title == "Your routine could not be saved")
    #expect(try you.model().alert == nil)
}

// MARK: Calendar

@MainActor
@Test func calendarAccessIsAskedOnlyFromItsButton() async throws {
    let you = try You(calendarSource: UnansweredCalendarSource())

    let before = try await you.open()
    try #require(before.calendar.allow).action()
    await you.store.waitForEffects()
    let after = try you.model()

    #expect(before.calendar.allow?.title == "Allow calendar access")
    #expect(before.calendar.text.hasPrefix("Let Tony plan around your meetings."))
    #expect(after.calendar.allow == nil)
    #expect(after.calendar.text.hasPrefix("Tony plans around your meetings."))
}
