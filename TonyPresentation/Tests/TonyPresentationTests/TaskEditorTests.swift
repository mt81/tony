import Foundation
import Testing
import TonyCore
@testable import TonyPresentation

private func newEditor() throws -> TaskEditor.State {
    .newTask(id: try Sample.identifier(1), stepID: try Sample.identifier(2), now: try Sample.november(10))
}

private let suggested = [
    Step(id: UUID(), name: "Load", mode: .active, duration: 600),
    Step(id: UUID(), name: "Wash", mode: .background, duration: 2700),
]

@Test func typingANewTaskNameAsksForSteps() throws {
    var state = try newEditor()

    let effects = TaskEditor.reduce(&state, .nameChanged("  Laundry "))

    #expect(state.task.name == "  Laundry ")
    #expect(effects == [.suggestSteps(forName: "Laundry")])
}

@Test func suggestedStepsReplaceUntouchedStepsForTheCurrentName() throws {
    var state = try newEditor()
    _ = TaskEditor.reduce(&state, .nameChanged("Laundry"))

    _ = TaskEditor.reduce(&state, .stepsSuggested(forName: "Laundry", steps: suggested))

    #expect(state.task.steps == suggested)
    #expect(state.showsSuggestion)
}

@Test func anAnswerForAnOldNameIsIgnored() throws {
    var state = try newEditor()
    _ = TaskEditor.reduce(&state, .nameChanged("Laundry day"))

    _ = TaskEditor.reduce(&state, .stepsSuggested(forName: "Laundry", steps: suggested))

    #expect(state.task.steps == state.initialSteps)
}

@Test func editedStepsAreNeverReplaced() throws {
    var state = try newEditor()
    _ = TaskEditor.reduce(&state, .nameChanged("Laundry"))
    _ = TaskEditor.reduce(&state, .stepsSuggested(forName: "Laundry", steps: suggested))
    _ = TaskEditor.reduce(&state, .stepMinutesChanged(id: suggested[0].id, minutes: 20))

    let effects = TaskEditor.reduce(&state, .nameChanged("Laundry and ironing"))
    _ = TaskEditor.reduce(&state, .stepsSuggested(forName: "Laundry and ironing", steps: nil))

    #expect(effects.isEmpty)
    #expect(state.task.steps.first?.duration == 1200)
    #expect(!state.showsSuggestion)
}

@Test func anUnknownNameRestoresTheInitialSteps() throws {
    var state = try newEditor()
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

@Test func editedTaskFoldsInCadenceDeadlineAndStepNames() throws {
    var state = try newEditor()
    let deadline = try Sample.november(20)
    for action: TaskEditor.Action in [
        .nameChanged(" Plants "),
        .cadenceKindChanged(.weekdays),
        .weekdayToggled(.monday, isOn: true),
        .weekdayToggled(.friday, isOn: true),
        .deadlineToggled(true),
        .deadlineChanged(deadline),
        .windowToggled(.evening, isOn: true),
        .avoidsRainToggled(true),
    ] {
        _ = TaskEditor.reduce(&state, action)
    }

    let task = state.editedTask

    #expect(task.name == "Plants")
    #expect(task.cadence == .weekdays([.monday, .friday]))
    #expect(task.mustHappenBy == deadline)
    #expect(task.requirements.windows == [.evening])
    #expect(task.requirements.avoidedWeather == [.rain])
    #expect(task.steps.map(\.name) == ["Plants"])
}

@Test func aOneTimeTaskHasNoCadence() throws {
    var state = try newEditor()
    _ = TaskEditor.reduce(&state, .nameChanged("Passport"))
    _ = TaskEditor.reduce(&state, .kindChanged(.oneTime))

    #expect(state.editedTask.cadence == nil)
}

@Test(arguments: [
    (name: "", cadence: TaskEditor.CadenceKind.afterCompletion, weekday: false, isValid: false),
    (name: "Plants", cadence: .afterCompletion, weekday: false, isValid: true),
    (name: "Plants", cadence: .weekdays, weekday: false, isValid: false),
    (name: "Plants", cadence: .weekdays, weekday: true, isValid: true),
])
func aTaskNeedsANameAndOnFixedDaysAWeekday(name: String, cadence: TaskEditor.CadenceKind, weekday: Bool, isValid: Bool) throws {
    var state = try newEditor()
    _ = TaskEditor.reduce(&state, .nameChanged(name))
    _ = TaskEditor.reduce(&state, .cadenceKindChanged(cadence))
    _ = TaskEditor.reduce(&state, .weekdayToggled(.tuesday, isOn: weekday))

    #expect(state.isValid == isValid)
}

@Test func theLastStepCannotBeDeleted() throws {
    var state = try newEditor()

    _ = TaskEditor.reduce(&state, .stepsDeleted([0]))
    #expect(state.task.steps.count == 1)

    _ = TaskEditor.reduce(&state, .stepAdded(id: try Sample.identifier(9)))
    _ = TaskEditor.reduce(&state, .stepsDeleted([0]))
    #expect(state.task.steps.map(\.id) == [try Sample.identifier(9)])
}
