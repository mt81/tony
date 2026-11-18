import Foundation
import Testing
import TonyCore
import TonyUIModels
@testable import TonyPresentation

@MainActor
private struct You {
    let repository = FakeRepository(tasks: [])
    let store: YouStore

    init(calendarSource: any CalendarSource = FakeCalendarSource(), languageService: (any LanguageService)? = nil, language: String = "en") throws {
        let now = try Sample.november(10)
        let coordinator = PlanCoordinator(repository: repository, calendarSource: calendarSource, calendar: Sample.calendar) { now }
        store = YouStore(
            repository: repository,
            calendarSource: calendarSource,
            coordinator: coordinator,
            languageService: languageService,
            calendar: Sample.calendar,
            locale: Locale(identifier: language),
            now: { now }
        )
    }

    func open(language: String = "en_GB") async throws -> YouViewModel {
        let viewModel = try viewModel(language: language)
        await viewModel.load()
        return viewModel
    }

    func viewModel(language: String = "en_GB") throws -> YouViewModel {
        YouViewModel(store: store, context: try Sample.context(language: language))
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
    you.store.changeTime(.workEnd, to: try time(8, 30))

    await you.store.save()

    #expect(you.store.state.editor != nil)
    #expect(await you.repository.routine() == nil)
}

// MARK: View model

@MainActor
@Test func aNewUserSeesTheStandardRoutineInBothLanguages() async throws {
    let you = try You()

    let english = try await you.open()
    let french = try you.viewModel(language: "fr_FR")

    #expect(english.name == "You")
    #expect(english.initial == nil)
    #expect(english.routine.lines == ["Home on Mon, Tue, Wed, Thu, Fri", "Workday 9:00 to 17:00", "Up around 7:00 · bed around 23:00"])
    #expect(french.name == "Toi")
    #expect(french.routine.lines == ["Maison : lun., mar., mer., jeu., ven.", "Travail de 9:00 à 17:00", "Lever vers 7:00 · coucher vers 23:00"])
}

@MainActor
@Test func savingTheFormStoresTheNameAndTheRoutine() async throws {
    let you = try You()
    try await you.open().routine.edit.action.execute()
    let editor = try #require(try you.viewModel().editor)

    editor.name.onChange.execute(" Matteo ")
    editor.days[1].picker.onSelect.execute(YouState.DayKind.office.rawValue)
    editor.days[5].picker.onSelect.execute(YouState.DayKind.home.rawValue)
    editor.workEnd.onChange.execute(try time(17, 30))
    editor.bedtime.onChange.execute(try time(22, 15))
    #expect(try #require(try you.viewModel().editor).save.isEnabled)
    await you.store.save()
    let viewModel = try you.viewModel()
    let stored = try #require(await you.repository.routine())

    #expect(editor.days.map(\.picker.title) == ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
    #expect(editor.days.map(\.picker.selectedID) == ["home", "home", "home", "home", "home", "off", "off"])
    #expect(viewModel.editor == nil)
    #expect(viewModel.name == "Matteo")
    #expect(viewModel.initial == "M")
    #expect(viewModel.routine.lines == ["Home on Mon, Wed, Thu, Fri, Sat · Office on Tue", "Workday 9:00 to 17:30", "Up around 7:00 · bed around 22:15"])
    #expect(stored.officeDays == [.tuesday])
    #expect(stored.workEnd == DateComponents(hour: 17, minute: 30))
    #expect(await you.repository.preferences().map(\.value) == ["Matteo"])
}

@MainActor
@Test func invalidWorkHoursDisableSavingAndSayWhy() async throws {
    let you = try You()
    try await you.open().routine.edit.action.execute()

    try #require(try you.viewModel().editor).workStart.onChange.execute(try time(18))
    let editor = try #require(try you.viewModel().editor)

    #expect(!editor.save.isEnabled)
    #expect(editor.workFooter == "Work has to end after it starts.")
}

@MainActor
@Test func aRoutineThatCannotBeSavedShowsAnAlert() async throws {
    let you = try You()
    try await you.open().routine.edit.action.execute()
    await you.repository.setFailsOnSave(true)

    await you.store.save()
    let alert = try #require(try you.viewModel().alert)
    alert.dismiss.action.execute()

    #expect(alert.title == "Your routine could not be saved")
    #expect(try you.viewModel().alert == nil)
}

@MainActor
@Test func theFormSaysWhileTonyIsReading() throws {
    let you = try You()
    let state = YouState()
    state.editor = YouState.Editor(name: "", routine: .standard, description: "Office on Tuesdays", reading: .inProgress)

    let editor = try #require(YouViewModel.editor(state, context: try Sample.context(language: "en"), store: you.store))

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
    try await you.open().routine.edit.action.execute()

    let empty = try #require(try you.viewModel().editor)
    empty.description.onChange.execute("Office on Tuesdays and Thursdays, until 5:30")
    await you.store.readDescription()
    let filled = try #require(try you.viewModel().editor)

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
        try await you.open().routine.edit.action.execute()
        you.store.changeDescription("Bureau le mardi")
        await you.store.readDescription()
    }

    #expect(try withoutModel.viewModel(language: "fr").editor?.descriptionFooter == "Tony n’a pas pu lire ça. Remplis le formulaire ci-dessous.")
    #expect(try wrongAnswer.viewModel().editor?.descriptionFooter == "Tony could not read that. Fill in the form below.")
    #expect(wrongAnswer.store.state.editor?.routine == .standard)
}

// MARK: Calendar

@MainActor
@Test func calendarAccessIsAskedOnlyFromItsButton() async throws {
    let you = try You(calendarSource: UnansweredCalendarSource())

    let viewModel = try await you.open()
    let before = viewModel.calendar
    await you.store.allowCalendar()
    let after = viewModel.calendar

    #expect(before.allow?.title == "Allow calendar access")
    #expect(before.text.hasPrefix("Let Tony plan around your meetings."))
    #expect(after.allow == nil)
    #expect(after.text.hasPrefix("Tony plans around your meetings."))
}
