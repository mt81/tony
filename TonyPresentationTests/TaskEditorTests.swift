import Foundation
import Testing
import TonyCore
@testable import TonyPresentation

private func newEditor() throws -> TaskEditor.State {
    .newTask(id: try Sample.identifier(1), stepID: try Sample.identifier(2), now: try Sample.november(10))
}

/// A new task past the composer, on the form.
private func reviewing() throws -> TaskEditor.State {
    var state = try newEditor()
    _ = TaskEditor.reduce(&state, .sentenceChanged("Laundry"))
    _ = TaskEditor.reduce(&state, .sentenceSent)
    _ = TaskEditor.reduce(&state, .sentenceRead(TaskDraft(name: "Laundry", cadence: .every(1, .week)), stepIDs: []))
    return state
}

private let suggested = [
    Step(id: UUID(), name: "Load", mode: .active, duration: 600),
    Step(id: UUID(), name: "Wash", mode: .background, duration: 2700),
]

// MARK: Composer

@Test func aNewTaskStartsOnTheComposerAndAnExistingOneOnTheForm() throws {
    let existing = TaskEditor.State(task: try Sample.task(3, "Vacuum"), isNew: false, today: try Sample.november(10))

    #expect(try newEditor().stage == .composing)
    #expect(existing.stage == .reviewing)
}

@Test func sendingTheSentenceReadsIt() throws {
    var state = try newEditor()
    _ = TaskEditor.reduce(&state, .sentenceChanged("  Water the plants every 5 days "))

    let effects = TaskEditor.reduce(&state, .sentenceSent)

    #expect(state.stage == .reading)
    #expect(effects == [.read(sentence: "Water the plants every 5 days", now: try Sample.november(10))])
    #expect(TaskEditor.reduce(&state, .sentenceSent).isEmpty)
}

@Test func anEmptySentenceIsNotSent() throws {
    var state = try newEditor()
    _ = TaskEditor.reduce(&state, .sentenceChanged("   "))

    #expect(TaskEditor.reduce(&state, .sentenceSent).isEmpty)
    #expect(state.stage == .composing)
}

@Test func returnInTheComposerSends() throws {
    var state = try newEditor()

    let effects = TaskEditor.reduce(&state, .sentenceChanged("Vacuum\n"))

    #expect(state.sentence == "Vacuum")
    #expect(effects == [.read(sentence: "Vacuum", now: try Sample.november(10))])
}

@Test func whatWasReadFillsTheForm() throws {
    var state = try newEditor()
    _ = TaskEditor.reduce(&state, .sentenceChanged("Water the plants every 5 days at home in the morning"))
    _ = TaskEditor.reduce(&state, .sentenceSent)
    let deadline = try Sample.november(20)
    let draft = TaskDraft(
        name: "Water the plants",
        icon: "🪴",
        cadence: .every(5, .day),
        requirements: Requirements(location: .home, windows: [.morning]),
        deadline: deadline
    )

    let effects = TaskEditor.reduce(&state, .sentenceRead(draft, stepIDs: []))

    #expect(state.stage == .reviewing)
    #expect(state.task.name == "Water the plants")
    #expect(state.task.icon == "🪴")
    #expect(state.task.cadence == .every(5, .day))
    #expect(state.task.requirements == Requirements(location: .home, windows: [.morning]))
    #expect(state.hasDeadline && state.deadline == deadline)
    #expect(effects == [.suggestSteps(forName: "Water the plants")])
}

@Test func subTasksReadInTheSentenceStandWithoutTheCatalogue() throws {
    var state = try newEditor()
    _ = TaskEditor.reduce(&state, .sentenceChanged("Laundry: wash, then fold"))
    _ = TaskEditor.reduce(&state, .sentenceSent)
    let subtasks = [
        StepTemplate(name: "Wash", mode: .active, duration: 600),
        StepTemplate(name: "Fold", mode: .active, duration: 900),
    ]
    let ids = [try Sample.identifier(5), try Sample.identifier(6)]

    let effects = TaskEditor.reduce(&state, .sentenceRead(TaskDraft(name: "Laundry", cadence: nil, subtasks: subtasks), stepIDs: ids))

    #expect(effects.isEmpty)
    #expect(state.task.steps == [subtasks[0].step(id: ids[0]), subtasks[1].step(id: ids[1])])
}

@Test func aTaskCannotBeSavedFromTheComposer() throws {
    var state = try newEditor()
    _ = TaskEditor.reduce(&state, .nameChanged("Plants"))

    #expect(!state.isValid)
}

// MARK: Steps

@Test func typingANewTaskNameAsksForSteps() throws {
    var state = try reviewing()

    let effects = TaskEditor.reduce(&state, .nameChanged("  Laundry "))

    #expect(state.task.name == "  Laundry ")
    #expect(effects == [.suggestSteps(forName: "Laundry")])
}

@Test func suggestedStepsReplaceUntouchedStepsForTheCurrentName() throws {
    var state = try reviewing()
    _ = TaskEditor.reduce(&state, .nameChanged("Laundry"))

    _ = TaskEditor.reduce(&state, .stepsSuggested(forName: "Laundry", steps: suggested))

    #expect(state.task.steps == suggested)
    #expect(state.suggestedSteps == suggested)
}

@Test func anAnswerForAnOldNameIsIgnored() throws {
    var state = try reviewing()
    _ = TaskEditor.reduce(&state, .nameChanged("Laundry day"))

    _ = TaskEditor.reduce(&state, .stepsSuggested(forName: "Laundry", steps: suggested))

    #expect(state.task.steps == state.initialSteps)
}

@Test func editedStepsAreNeverReplaced() throws {
    var state = try reviewing()
    _ = TaskEditor.reduce(&state, .nameChanged("Laundry"))
    _ = TaskEditor.reduce(&state, .stepsSuggested(forName: "Laundry", steps: suggested))
    _ = TaskEditor.reduce(&state, .stepMinutesChanged(id: suggested[0].id, minutes: 20))

    let effects = TaskEditor.reduce(&state, .nameChanged("Laundry and ironing"))
    _ = TaskEditor.reduce(&state, .stepsSuggested(forName: "Laundry and ironing", steps: nil))

    #expect(effects.isEmpty)
    #expect(state.task.steps.first?.duration == 1200)
}

@Test func anUnknownNameRestoresTheInitialSteps() throws {
    var state = try reviewing()
    _ = TaskEditor.reduce(&state, .nameChanged("Laundry"))
    _ = TaskEditor.reduce(&state, .stepsSuggested(forName: "Laundry", steps: suggested))
    _ = TaskEditor.reduce(&state, .nameChanged("Passport"))

    _ = TaskEditor.reduce(&state, .stepsSuggested(forName: "Passport", steps: nil))

    #expect(state.task.steps == state.initialSteps)
}

@Test func anExistingTaskNeverAsksForSteps() throws {
    var state = TaskEditor.State(task: try Sample.task(3, "Vacuum"), isNew: false, today: try Sample.november(10))

    #expect(TaskEditor.reduce(&state, .nameChanged("Laundry")).isEmpty)
}

@Test func theLastStepCannotBeDeleted() throws {
    var state = try reviewing()

    _ = TaskEditor.reduce(&state, .stepsDeleted([0]))
    #expect(state.task.steps.count == 1)

    _ = TaskEditor.reduce(&state, .stepAdded(id: try Sample.identifier(9)))
    _ = TaskEditor.reduce(&state, .stepsDeleted([0]))
    #expect(state.task.steps.map(\.id) == [try Sample.identifier(9)])
}

// MARK: Repeats

@Test(arguments: [
    (TaskEditor.Repeats.never, nil),
    (.everyDay, Cadence.every(1, .day)),
    (.weekdays, .weekdays([.monday, .tuesday, .wednesday, .thursday, .friday])),
    (.everyWeek, .every(1, .week)),
    (.everyTwoWeeks, .every(2, .week)),
    (.everyMonth, .every(1, .month)),
    (.everyYear, .every(1, .year)),
    (.timesAWeek, .timesPerWeek(3)),
] as [(TaskEditor.Repeats, Cadence?)])
func eachRepeatsChoiceSetsItsCadence(repeats: TaskEditor.Repeats, cadence: Cadence?) throws {
    var state = try reviewing()

    _ = TaskEditor.reduce(&state, .repeatsChanged(repeats))

    #expect(state.task.cadence == cadence)
    #expect(state.repeats == repeats)
}

@Test func customKeepsTheCadenceAndStaysPicked() throws {
    var state = try reviewing()

    _ = TaskEditor.reduce(&state, .repeatsChanged(.custom))
    #expect(state.task.cadence == .every(1, .week))
    #expect(state.repeats == .custom)

    _ = TaskEditor.reduce(&state, .customUnitChanged(.month))
    _ = TaskEditor.reduce(&state, .intervalCountChanged(3))
    #expect(state.task.cadence == .every(3, .month))
    #expect(state.repeats == .custom)
}

@Test func customFromNeverStartsEveryTwoDays() throws {
    var state = try reviewing()
    _ = TaskEditor.reduce(&state, .repeatsChanged(.never))

    _ = TaskEditor.reduce(&state, .repeatsChanged(.custom))

    #expect(state.task.cadence == .every(2, .day))
}

@Test func aSmallerUnitKeepsTheCountItAllows() throws {
    var state = try reviewing()
    _ = TaskEditor.reduce(&state, .repeatsChanged(.custom))
    _ = TaskEditor.reduce(&state, .customUnitChanged(.day))
    _ = TaskEditor.reduce(&state, .intervalCountChanged(40))

    _ = TaskEditor.reduce(&state, .customUnitChanged(.year))

    #expect(state.task.cadence == .every(10, .year))
}

@Test func weekdaysRepeatEveryWeekAndClearingThemGoesBackToEveryWeek() throws {
    var state = try reviewing()
    _ = TaskEditor.reduce(&state, .repeatsChanged(.custom))

    _ = TaskEditor.reduce(&state, .weekdayToggled(.monday, isOn: true))
    _ = TaskEditor.reduce(&state, .weekdayToggled(.thursday, isOn: true))
    #expect(state.task.cadence == .weekdays([.monday, .thursday]))

    _ = TaskEditor.reduce(&state, .weekdayToggled(.monday, isOn: false))
    _ = TaskEditor.reduce(&state, .weekdayToggled(.thursday, isOn: false))
    #expect(state.task.cadence == .every(1, .week))
}

@Test func theWeeklyGoalIsKeptWhileOtherChoicesAreTried() throws {
    var state = try reviewing()
    _ = TaskEditor.reduce(&state, .repeatsChanged(.timesAWeek))
    _ = TaskEditor.reduce(&state, .timesPerWeekChanged(5))

    _ = TaskEditor.reduce(&state, .repeatsChanged(.everyDay))
    _ = TaskEditor.reduce(&state, .repeatsChanged(.timesAWeek))

    #expect(state.task.cadence == .timesPerWeek(5))
}

// MARK: Counted from

@Test func aFixedScheduleStartsTodayUntilItsStartIsChanged() throws {
    var state = try reviewing()
    _ = TaskEditor.reduce(&state, .repeatsChanged(.everyMonth))

    _ = TaskEditor.reduce(&state, .countedFromChanged(isFixed: true))
    #expect(state.task.cadence == .interval(Cadence.Interval(count: 1, unit: .month), countedFrom: .schedule(from: try Sample.november(10))))

    _ = TaskEditor.reduce(&state, .scheduleStartChanged(try Sample.november(15)))
    _ = TaskEditor.reduce(&state, .repeatsChanged(.everyYear))
    #expect(state.task.cadence == .interval(Cadence.Interval(count: 1, unit: .year), countedFrom: .schedule(from: try Sample.november(15))))

    _ = TaskEditor.reduce(&state, .countedFromChanged(isFixed: false))
    #expect(state.task.cadence == .every(1, .year))
}

// MARK: When it fits

@Test func anyTimeAndAnyWeatherClearTheirChoices() throws {
    var state = try reviewing()
    _ = TaskEditor.reduce(&state, .windowToggled(.morning, isOn: true))
    _ = TaskEditor.reduce(&state, .windowToggled(.evening, isOn: true))
    _ = TaskEditor.reduce(&state, .weatherToggled(.rain, isOn: true))
    #expect(state.task.requirements.windows == [.morning, .evening])
    #expect(state.task.requirements.avoidedWeather == [.rain])

    _ = TaskEditor.reduce(&state, .windowToggled(nil, isOn: true))
    _ = TaskEditor.reduce(&state, .weatherToggled(nil, isOn: true))

    #expect(state.task.requirements.windows.isEmpty)
    #expect(state.task.requirements.avoidedWeather.isEmpty)
}

// MARK: Saving

@Test func editedTaskFoldsInKindDeadlineAndStepNames() throws {
    var state = try reviewing()
    let deadline = try Sample.november(20)
    for action: TaskEditor.Action in [
        .nameChanged(" Plants "),
        .repeatsChanged(.timesAWeek),
        .deadlineToggled(true),
        .deadlineChanged(deadline),
    ] {
        _ = TaskEditor.reduce(&state, action)
    }

    let task = state.editedTask

    #expect(task.name == "Plants")
    #expect(task.kind == .goal)
    #expect(task.cadence == .timesPerWeek(3))
    #expect(task.mustHappenBy == deadline)
    #expect(task.steps.map(\.name) == ["Plants"])
}

@Test(arguments: [
    (TaskEditor.Repeats.never, TonyTask.Kind.oneTime),
    (.everyWeek, .recurring),
    (.weekdays, .recurring),
    (.timesAWeek, .goal),
] as [(TaskEditor.Repeats, TonyTask.Kind)])
func theKindFollowsTheRepeats(repeats: TaskEditor.Repeats, kind: TonyTask.Kind) throws {
    var state = try reviewing()

    _ = TaskEditor.reduce(&state, .repeatsChanged(repeats))

    #expect(state.editedTask.kind == kind)
}

@Test(arguments: [
    (name: "", weekday: nil, isValid: false),
    (name: "Plants", weekday: nil, isValid: true),
    (name: "Plants", weekday: Locale.Weekday.tuesday, isValid: true),
] as [(name: String, weekday: Locale.Weekday?, isValid: Bool)])
func aTaskNeedsAName(name: String, weekday: Locale.Weekday?, isValid: Bool) throws {
    var state = try reviewing()
    _ = TaskEditor.reduce(&state, .nameChanged(name))
    if let weekday {
        _ = TaskEditor.reduce(&state, .repeatsChanged(.custom))
        _ = TaskEditor.reduce(&state, .weekdayToggled(weekday, isOn: true))
    }

    #expect(state.isValid == isValid)
}

@Test func aNameStaysOnOneLine() throws {
    var state = try reviewing()

    _ = TaskEditor.reduce(&state, .nameChanged("Water\nthe plants"))

    #expect(state.task.name == "Waterthe plants")
}
