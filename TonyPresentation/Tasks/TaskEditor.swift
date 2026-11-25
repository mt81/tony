import Foundation
import TonyCore

/// The task form. A new task starts from a sentence the user types; the form then shows what Tony read, to review.
/// The feature that shows it (Tasks, Today) saves the task, reads the sentence and looks up the steps.
public enum TaskEditor {
    public enum Stage: Sendable, Equatable {
        /// The user types the task in one sentence.
        case composing
        /// The sentence is being read.
        case reading
        /// The form shows the task, to review and change.
        case reviewing
    }

    /// The choices of the Repeats list. `custom` is any other cadence.
    public enum Repeats: String, Sendable, CaseIterable {
        case never
        case everyDay
        case weekdays
        case everyWeek
        case everyTwoWeeks
        case everyMonth
        case everyYear
        case timesAWeek
        case custom
    }

    public struct State: Sendable, Equatable {
        public var task: TonyTask
        public var isNew: Bool
        public var stage: Stage
        /// The sentence typed in the composer.
        public var sentence: String
        public var today: Date
        /// What an interval counts from, kept while the user tries other choices.
        public var countedFrom: Cadence.Anchor
        /// The weekly goal, kept while the user tries other choices.
        public var timesPerWeek: Int
        /// Custom was picked, so its choices show even when they match a preset.
        public var isCustom: Bool
        public var hasDeadline: Bool
        public var deadline: Date
        /// The steps the task started with, which the catalogue may replace while they are untouched.
        public var initialSteps: [Step]
        public var suggestedSteps: [Step]?

        /// An existing task opens on the form.
        public init(task: TonyTask, isNew: Bool, today: Date) {
            self.task = task
            self.isNew = isNew
            self.today = today
            stage = isNew ? .composing : .reviewing
            sentence = ""
            hasDeadline = task.mustHappenBy != nil
            deadline = task.mustHappenBy ?? today
            initialSteps = task.steps
            suggestedSteps = nil
            countedFrom = .lastCompletion
            timesPerWeek = 3
            isCustom = false
            switch task.cadence {
            case .interval(_, let anchor): countedFrom = anchor
            case .timesPerWeek(let times): timesPerWeek = times
            case .weekdays, nil: break
            }
            isCustom = preset == .custom
        }

        /// A blank task with the one step every task has, opening on the composer.
        public static func newTask(id: UUID, stepID: UUID, now: Date) -> State {
            let task = TonyTask(
                id: id,
                name: "",
                icon: "✅",
                kind: .recurring,
                rank: 0,
                cadence: .every(1, .week),
                steps: [Step(id: stepID, name: "", mode: .active, duration: 30 * 60)],
                createdAt: now
            )
            return State(task: task, isNew: true, today: now)
        }

        public var trimmedName: String {
            task.name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        public var trimmedSentence: String {
            sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        public var isValid: Bool {
            guard stage == .reviewing, !trimmedName.isEmpty else { return false }
            if case .weekdays(let weekdays) = task.cadence {
                return !weekdays.isEmpty
            }
            return true
        }

        public var stepsAreUntouched: Bool {
            task.steps == initialSteps || task.steps == suggestedSteps
        }

        public var repeats: Repeats {
            isCustom ? .custom : preset
        }

        /// The choice the cadence matches; custom when it matches none.
        var preset: Repeats {
            switch task.cadence {
            case nil: .never
            case .timesPerWeek: .timesAWeek
            case .weekdays(let weekdays): weekdays == TaskEditor.workweek ? .weekdays : .custom
            case .interval(let interval, _):
                switch (interval.count, interval.unit) {
                case (1, .day): .everyDay
                case (1, .week): .everyWeek
                case (2, .week): .everyTwoWeeks
                case (1, .month): .everyMonth
                case (1, .year): .everyYear
                default: .custom
                }
            }
        }

        /// The task as the form describes it: kind and deadline folded in, unnamed steps named after the task.
        public var editedTask: TonyTask {
            var edited = task
            edited.name = trimmedName
            edited.kind = TonyTask.Kind(cadence: task.cadence)
            edited.mustHappenBy = hasDeadline ? deadline : nil
            for index in edited.steps.indices where edited.steps[index].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                edited.steps[index].name = trimmedName
            }
            return edited
        }

        fileprivate mutating func setInterval(_ interval: Cadence.Interval) {
            task.cadence = .interval(interval, countedFrom: countedFrom)
        }
    }

    public enum Action: Sendable, Equatable {
        case sentenceChanged(String)
        case sentenceSent
        /// What Tony read in the sentence.
        case sentenceRead(TaskDraft, stepIDs: [UUID])
        case nameChanged(String)
        case iconChanged(String)
        case repeatsChanged(Repeats)
        case timesPerWeekChanged(Int)
        case customUnitChanged(Cadence.Interval.Unit)
        case intervalCountChanged(Int)
        case weekdayToggled(Locale.Weekday, isOn: Bool)
        case countedFromChanged(isFixed: Bool)
        case scheduleStartChanged(Date)
        case deadlineToggled(Bool)
        case deadlineChanged(Date)
        case locationChanged(Location?)
        /// A time of day turned on or off; nil is "Any time", which clears them.
        case windowToggled(Window?, isOn: Bool)
        /// Weather the task needs turned on or off; nil is "Any weather", which clears it.
        case weatherToggled(WeatherCondition?, isOn: Bool)
        case stepNameChanged(id: UUID, name: String)
        case stepMinutesChanged(id: UUID, minutes: Int)
        case stepAdded(id: UUID)
        case stepsMoved(from: IndexSet, to: Int)
        case stepsDeleted(IndexSet)
        /// The catalogue's answer for a name; nil when it does not know it.
        case stepsSuggested(forName: String, steps: [Step]?)
    }

    public enum Effect: Sendable, Equatable {
        case read(sentence: String, now: Date)
        case suggestSteps(forName: String)
    }

    static let workweek: Set<Locale.Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    public static func reduce(_ state: inout State, _ action: Action) -> [Effect] {
        switch action {
        case .sentenceChanged(let sentence):
            // The composer grows over several lines, so return types a line break: it sends instead.
            guard sentence.contains(where: \.isNewline) else {
                state.sentence = sentence
                break
            }
            state.sentence = String(sentence.filter { !$0.isNewline })
            return reduce(&state, .sentenceSent)
        case .sentenceSent:
            guard state.stage == .composing, !state.trimmedSentence.isEmpty else { break }
            state.stage = .reading
            return [.read(sentence: state.trimmedSentence, now: state.today)]
        case .sentenceRead(let draft, let stepIDs):
            guard state.stage == .reading else { break }
            return fill(&state, with: draft, stepIDs: stepIDs)
        case .nameChanged(let name):
            // The name field grows over several lines; a name stays on one.
            state.task.name = String(name.filter { !$0.isNewline })
            return state.isNew && state.stepsAreUntouched ? [.suggestSteps(forName: state.trimmedName)] : []
        case .iconChanged(let text):
            // The field shows one emoji: what is typed after it replaces it, and clearing it keeps it.
            if let picked = text.last {
                state.task.icon = String(picked)
            }
        case .repeatsChanged(let repeats):
            apply(repeats, to: &state)
        case .timesPerWeekChanged(let times):
            state.timesPerWeek = times
            state.task.cadence = .timesPerWeek(times)
        case .customUnitChanged(let unit):
            let count = state.task.cadence?.interval?.count ?? 1
            state.setInterval(Cadence.Interval(count: min(count, unit.maximumCount), unit: unit))
        case .intervalCountChanged(let count):
            guard let interval = state.task.cadence?.interval else { break }
            state.setInterval(Cadence.Interval(count: count, unit: interval.unit))
        case .weekdayToggled(let weekday, let isOn):
            var weekdays: Set<Locale.Weekday> = if case .weekdays(let days) = state.task.cadence { days } else { [] }
            weekdays.set(weekday, isOn)
            if weekdays.isEmpty {
                state.setInterval(Cadence.Interval(count: 1, unit: .week))
            } else {
                state.task.cadence = .weekdays(weekdays)
            }
        case .countedFromChanged(let isFixed):
            state.countedFrom = isFixed ? .schedule(from: state.today) : .lastCompletion
            if let interval = state.task.cadence?.interval {
                state.setInterval(interval)
            }
        case .scheduleStartChanged(let date):
            state.countedFrom = .schedule(from: date)
            if let interval = state.task.cadence?.interval {
                state.setInterval(interval)
            }
        case .deadlineToggled(let isOn):
            state.hasDeadline = isOn
        case .deadlineChanged(let date):
            state.deadline = date
        case .locationChanged(let location):
            state.task.requirements.location = location
        case .windowToggled(let window, let isOn):
            if let window {
                state.task.requirements.windows.set(window, isOn)
            } else if isOn {
                state.task.requirements.windows = []
            }
        case .weatherToggled(let condition, let isOn):
            if let condition {
                state.task.requirements.neededWeather.set(condition, isOn)
            } else if isOn {
                state.task.requirements.neededWeather = []
            }
        case .stepNameChanged(let id, let name):
            state.updateStep(id) { $0.name = name }
        case .stepMinutesChanged(let id, let minutes):
            state.updateStep(id) { $0.duration = TimeInterval(minutes * 60) }
        case .stepAdded(let id):
            state.task.steps.append(Step(id: id, name: "", mode: .active, duration: 30 * 60))
        case .stepsMoved(let source, let destination):
            state.task.steps.move(fromOffsets: source, toOffset: destination)
        case .stepsDeleted(let offsets):
            if state.task.steps.count > offsets.count {
                state.task.steps.remove(atOffsets: offsets)
            }
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

    private static func apply(_ repeats: Repeats, to state: inout State) {
        state.isCustom = repeats == .custom
        switch repeats {
        case .never: state.task.cadence = nil
        case .everyDay: state.setInterval(Cadence.Interval(count: 1, unit: .day))
        case .weekdays: state.task.cadence = .weekdays(workweek)
        case .everyWeek: state.setInterval(Cadence.Interval(count: 1, unit: .week))
        case .everyTwoWeeks: state.setInterval(Cadence.Interval(count: 2, unit: .week))
        case .everyMonth: state.setInterval(Cadence.Interval(count: 1, unit: .month))
        case .everyYear: state.setInterval(Cadence.Interval(count: 1, unit: .year))
        case .timesAWeek: state.task.cadence = .timesPerWeek(state.timesPerWeek)
        case .custom:
            // Custom starts from what is there; from never or a weekly goal, it starts every 2 days.
            if state.task.cadence == nil || state.preset == .timesAWeek {
                state.setInterval(Cadence.Interval(count: 2, unit: .day))
            }
        }
    }

    /// Fills a new task's form with what was read in the sentence, and shows the form.
    /// Sub tasks the sentence gave stand, with these ids; otherwise the catalogue is asked for the steps.
    static func fill(_ state: inout State, with draft: TaskDraft, stepIDs: [UUID]) -> [Effect] {
        state.stage = .reviewing
        state.task.cadence = draft.cadence
        state.isCustom = state.preset == .custom
        if case .interval(_, let anchor) = draft.cadence {
            state.countedFrom = anchor
        }
        if case .timesPerWeek(let times) = draft.cadence {
            state.timesPerWeek = times
        }
        state.task.icon = draft.icon ?? state.task.icon
        state.task.requirements = draft.requirements
        if let deadline = draft.deadline {
            state.hasDeadline = true
            state.deadline = deadline
        }
        if !draft.subtasks.isEmpty, draft.subtasks.count == stepIDs.count {
            state.task.name = draft.name
            state.task.steps = zip(draft.subtasks, stepIDs).map { $0.step(id: $1) }
            state.initialSteps = state.task.steps
            return []
        }
        return reduce(&state, .nameChanged(draft.name))
    }
}

extension TaskEditor {
    /// Reads the sentence the user typed: the rules, then the model when there is one.
    static func read(
        sentence: String,
        now: Date,
        calendar: Calendar,
        locale: Locale,
        service: (any LanguageService)?
    ) async -> Action {
        let draft = await TaskSentenceParser.draft(
            from: sentence,
            locale: locale,
            instructions: ModelInstructions.task(locale, now: now, calendar: calendar),
            service: service,
            now: now,
            calendar: calendar
        )
        return .sentenceRead(draft, stepIDs: draft.subtasks.map { _ in UUID() })
    }
}

extension Cadence {
    var interval: Interval? {
        if case .interval(let interval, _) = self { interval } else { nil }
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
