import Foundation
import TonyCore

/// The task form. Part of the Tasks feature, which shows it, saves it and looks up its steps.
public enum TaskEditor {
    public enum CadenceKind: String, Sendable, CaseIterable {
        case afterCompletion
        case weekdays
        case timesPerWeek
    }

    public struct State: Sendable, Equatable {
        public var task: TonyTask
        public var isNew: Bool
        public var cadenceKind: CadenceKind
        public var everyDays: Int
        public var weekdays: Set<Locale.Weekday>
        public var timesPerWeek: Int
        public var hasDeadline: Bool
        public var deadline: Date
        /// The steps the task started with, which the catalogue may replace while they are untouched.
        public var initialSteps: [Step]
        public var suggestedSteps: [Step]?

        public init(task: TonyTask, isNew: Bool, today: Date) {
            self.task = task
            self.isNew = isNew
            hasDeadline = task.mustHappenBy != nil
            deadline = task.mustHappenBy ?? today
            initialSteps = task.steps
            suggestedSteps = nil
            cadenceKind = .afterCompletion
            everyDays = 7
            weekdays = []
            timesPerWeek = 3
            switch task.cadence {
            case .afterCompletion(let days): everyDays = days
            case .weekdays(let days): (cadenceKind, weekdays) = (.weekdays, days)
            case .timesPerWeek(let times): (cadenceKind, timesPerWeek) = (.timesPerWeek, times)
            case nil: break
            }
        }

        /// A blank recurring task with the one step every task has.
        public static func newTask(id: UUID, stepID: UUID, now: Date) -> State {
            let task = TonyTask(
                id: id,
                name: "",
                icon: "✅",
                kind: .recurring,
                rank: 0,
                cadence: .afterCompletion(days: 7),
                steps: [Step(id: stepID, name: "", mode: .active, duration: 30 * 60)],
                createdAt: now
            )
            return State(task: task, isNew: true, today: now)
        }

        public var trimmedName: String {
            task.name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        public var isValid: Bool {
            let needsWeekdays = task.kind != .oneTime && cadenceKind == .weekdays
            return !trimmedName.isEmpty && !(needsWeekdays && weekdays.isEmpty)
        }

        public var stepsAreUntouched: Bool {
            task.steps == initialSteps || task.steps == suggestedSteps
        }

        public var showsSuggestion: Bool {
            suggestedSteps != nil && task.steps == suggestedSteps
        }

        /// The task as the form describes it: cadence and deadline folded in, unnamed steps named after the task.
        public var editedTask: TonyTask {
            var edited = task
            edited.name = trimmedName
            edited.mustHappenBy = hasDeadline ? deadline : nil
            edited.cadence =
                if task.kind == .oneTime {
                    nil
                } else {
                    switch cadenceKind {
                    case .afterCompletion: .afterCompletion(days: everyDays)
                    case .weekdays: .weekdays(weekdays)
                    case .timesPerWeek: .timesPerWeek(timesPerWeek)
                    }
                }
            for index in edited.steps.indices where edited.steps[index].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                edited.steps[index].name = trimmedName
            }
            return edited
        }
    }

    public enum Action: Sendable, Equatable {
        case nameChanged(String)
        case iconChanged(String)
        case kindChanged(TonyTask.Kind)
        case cadenceKindChanged(CadenceKind)
        case everyDaysChanged(Int)
        case weekdayToggled(Locale.Weekday, isOn: Bool)
        case timesPerWeekChanged(Int)
        case locationChanged(Location?)
        case windowToggled(Window, isOn: Bool)
        case avoidsRainToggled(Bool)
        case costsMoneyToggled(Bool)
        case stepNameChanged(id: UUID, name: String)
        case stepModeChanged(id: UUID, mode: Step.Mode)
        case stepMinutesChanged(id: UUID, minutes: Int)
        case stepGapChanged(id: UUID, minutes: Int)
        case stepAdded(id: UUID)
        case stepsMoved(from: IndexSet, to: Int)
        case stepsDeleted(IndexSet)
        case deadlineToggled(Bool)
        case deadlineChanged(Date)
        /// The catalogue's answer for a name; nil when it does not know it.
        case stepsSuggested(forName: String, steps: [Step]?)
    }

    public enum Effect: Sendable, Equatable {
        case suggestSteps(forName: String)
    }

    public static func reduce(_ state: inout State, _ action: Action) -> [Effect] {
        switch action {
        case .nameChanged(let name):
            state.task.name = name
            return state.isNew && state.stepsAreUntouched ? [.suggestSteps(forName: state.trimmedName)] : []
        case .iconChanged(let icon):
            state.task.icon = icon
        case .kindChanged(let kind):
            state.task.kind = kind
        case .cadenceKindChanged(let kind):
            state.cadenceKind = kind
        case .everyDaysChanged(let days):
            state.everyDays = days
        case .weekdayToggled(let weekday, let isOn):
            state.weekdays.set(weekday, isOn)
        case .timesPerWeekChanged(let times):
            state.timesPerWeek = times
        case .locationChanged(let location):
            state.task.requirements.location = location
        case .windowToggled(let window, let isOn):
            state.task.requirements.windows.set(window, isOn)
        case .avoidsRainToggled(let isOn):
            state.task.requirements.avoidedWeather.set(.rain, isOn)
        case .costsMoneyToggled(let isOn):
            state.task.requirements.costsMoney = isOn
        case .stepNameChanged(let id, let name):
            state.updateStep(id) { $0.name = name }
        case .stepModeChanged(let id, let mode):
            state.updateStep(id) { $0.mode = mode }
        case .stepMinutesChanged(let id, let minutes):
            state.updateStep(id) { $0.duration = TimeInterval(minutes * 60) }
        case .stepGapChanged(let id, let minutes):
            state.updateStep(id) { $0.minimumGapToNextStep = TimeInterval(minutes * 60) }
        case .stepAdded(let id):
            state.task.steps.append(Step(id: id, name: "", mode: .active, duration: 30 * 60))
        case .stepsMoved(let source, let destination):
            state.task.steps.move(fromOffsets: source, toOffset: destination)
        case .stepsDeleted(let offsets):
            if state.task.steps.count > offsets.count {
                state.task.steps.remove(atOffsets: offsets)
            }
        case .deadlineToggled(let isOn):
            state.hasDeadline = isOn
        case .deadlineChanged(let date):
            state.deadline = date
        case .stepsSuggested(let name, let steps):
            guard state.isNew, name == state.trimmedName, state.stepsAreUntouched else { break }
            if let steps, !steps.isEmpty {
                state.task.steps = steps
                state.suggestedSteps = steps
            } else {
                state.task.steps = state.initialSteps
                state.suggestedSteps = nil
            }
        }
        return []
    }
}

extension TaskEditor.State {
    fileprivate mutating func updateStep(_ id: UUID, _ change: (inout Step) -> Void) {
        guard let index = task.steps.firstIndex(where: { $0.id == id }) else { return }
        change(&task.steps[index])
    }
}

extension Set {
    fileprivate mutating func set(_ element: Element, _ isMember: Bool) {
        if isMember {
            insert(element)
        } else {
            remove(element)
        }
    }
}
