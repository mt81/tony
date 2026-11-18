import Foundation
import Testing
import TonyCore
import TonyUIModels
@testable import TonyPresentation

@MainActor
private struct You {
    let repository = FakeRepository(tasks: [])
    let store: YouStore
    let now: Date

    init(calendarSource: any CalendarSource = FakeCalendarSource(), languageService: (any LanguageService)? = nil, language: String = "en") throws {
        let now = try Sample.november(10)
        let coordinator = PlanCoordinator(repository: repository, calendarSource: calendarSource, calendar: Sample.calendar) { now }
        self.now = now
        store = YouStore(
            repository: repository,
            calendarSource: calendarSource,
            coordinator: coordinator,
            languageService: languageService,
            calendar: Sample.calendar,
            locale: Locale(identifier: language)
        )
    }

    func open(language: String = "en_GB") async throws -> YouScreenDataModel {
        try await model(language: language).load()
        return try model(language: language)
    }

    func model(language: String = "en_GB") throws -> YouScreenDataModel {
        YouReducer.reduce(store.state, context: try Sample.context(language: language), store: store)
    }
}

private func time(_ hour: Int, _ minute: Int = 0) throws -> Date {
    try #require(Sample.calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: hour, minute: minute)))
}

// MARK: Store

@MainActor
@Test func changingADayMovesItBetweenHomeOfficeAndOff() throws {
    let you = try You()
    you.store.startEditing()

    you.store.changeDay(.tuesday, to: .office)
    you.store.changeDay(.friday, to: .off)
    you.store.changeDay(.saturday, to: .home)

    #expect(you.store.state.editor?.routine.homeDays == [.monday, .wednesday, .thursday, .saturday])
    #expect(you.store.state.editor?.routine.officeDays == [.tuesday])
    #expect(you.store.state.routine == .standard)
}

@MainActor
@Test func workThatEndsBeforeItStartsIsNotSaved() async throws {
    let you = try You()
    you.store.startEditing()
    you.store.changeTime(.workEnd, to: DateComponents(hour: 8, minute: 30))

    await you.store.save(now: you.now)

    #expect(you.store.state.editor != nil)
    #expect(await you.repository.routine() == nil)
}

// MARK: Reducer

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
    editor.days[1].picker.onSelect(YouState.DayKind.office.rawValue)
    editor.days[5].picker.onSelect(YouState.DayKind.home.rawValue)
    editor.workEnd.onChange(try time(17, 30))
    editor.bedtime.onChange(try time(22, 15))
    #expect(try #require(try you.model().editor).save.isEnabled)
    await you.store.save(now: you.now)
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

    await you.store.save(now: you.now)
    let alert = try #require(try you.model().alert)
    alert.dismiss.action()

    #expect(alert.title == "Your routine could not be saved")
    #expect(try you.model().alert == nil)
}

@MainActor
@Test func theFormSaysWhileTonyIsReading() throws {
    let you = try You()
    var state = YouState()
    state.editor = YouState.Editor(name: "", routine: .standard, description: "Office on Tuesdays", reading: .inProgress)

    let editor = try #require(YouReducer.reduce(state, context: try Sample.context(language: "en"), store: you.store).editor)

    #expect(editor.descriptionFooter == "Tony is reading…")
}

// MARK: Describing the week

@MainActor
@Test func aDescriptionTheModelReadsFillsTheFormWithoutSavingIt() async throws {
    var read = Routine.standard
    read.homeDays = [.monday, .wednesday, .friday]
    read.officeDays = [.tuesday, .thursday]
    read.workEnd = DateComponents(hour: 17, minute: 30)
    let service = FakeLanguageService(routine: read)
    let you = try You(languageService: service)
    try await you.open().routine.edit.action()

    let empty = try #require(try you.model().editor)
    empty.description.onChange("Office on Tuesdays and Thursdays, until 5:30")
    await you.store.readDescription()
    let filled = try #require(try you.model().editor)

    #expect(empty.descriptionFooter == nil)
    #expect(filled.descriptionFooter == "Tony filled in the form below. Check it before you save.")
    #expect(filled.days.map(\.picker.selectedID) == ["home", "office", "home", "office", "home", "off", "off"])
    #expect(await you.repository.routine() == nil)
    #expect(service.requests.first?.plan == """
        Current routine:
        Home days: Monday, Tuesday, Wednesday, Thursday, Friday
        Office days: none
        Work from 09:00 to 17:00
        Up at 07:00, bed at 23:00
        Description: Office on Tuesdays and Thursdays, until 5:30
        """)
    #expect(service.requests.first?.instructions.hasSuffix("The description is in English.") == true)
}

@MainActor
@Test func aDescriptionThatCannotBeReadLeavesTheFormAndSaysSo() async throws {
    var backwards = Routine.standard
    backwards.workEnd = DateComponents(hour: 6, minute: 0)
    let withoutModel = try You(language: "fr")
    let wrongAnswer = try You(languageService: FakeLanguageService(routine: backwards))

    for you in [withoutModel, wrongAnswer] {
        try await you.open().routine.edit.action()
        you.store.changeDescription("Bureau le mardi")
        await you.store.readDescription()
    }

    #expect(try withoutModel.model(language: "fr").editor?.descriptionFooter == "Tony n’a pas pu lire ça. Remplis le formulaire ci-dessous.")
    #expect(try wrongAnswer.model().editor?.descriptionFooter == "Tony could not read that. Fill in the form below.")
    #expect(wrongAnswer.store.state.editor?.routine == .standard)
}

// MARK: Calendar

@MainActor
@Test func calendarAccessIsAskedOnlyFromItsButton() async throws {
    let you = try You(calendarSource: UnansweredCalendarSource())

    let before = try await you.open()
    await you.store.allowCalendar()
    let after = try you.model()

    #expect(before.calendar.allow?.title == "Allow calendar access")
    #expect(before.calendar.text.hasPrefix("Let Tony plan around your meetings."))
    #expect(after.calendar.allow == nil)
    #expect(after.calendar.text.hasPrefix("Tony plans around your meetings."))
}
