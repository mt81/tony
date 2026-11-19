import Foundation
import MemberwiseInit

/// A task as read from one sentence. It fills the task form; nothing is saved before the user confirms.
@MemberwiseInit(.public)
public struct TaskDraft: Sendable, Hashable {
    public var name: String
    public var cadence: Cadence?

    /// A number of times a week is a goal, another cadence a recurring task, and no cadence a one-time task.
    public var kind: TonyTask.Kind {
        switch cadence {
        case .timesPerWeek: .goal
        case .interval, .weekdays: .recurring
        case nil: .oneTime
        }
    }
}

/// Reads a sentence as a task. The rules go first: what they understand needs no model.
/// The model is asked only for sentences the rules find no cadence in, and its answer is checked.
public enum TaskSentenceParser {
    public static func draft(
        from sentence: String,
        locale: Locale,
        instructions: String,
        service: (any LanguageService)?
    ) async -> TaskDraft {
        let byRules = CadenceRules.draft(from: sentence, locale: locale)
        guard
            byRules.cadence == nil,
            let fromModel = try? await service?.taskDraft(instructions: instructions, sentence: sentence),
            isValid(fromModel, for: sentence)
        else {
            return byRules
        }
        return TaskDraft(name: fromModel.name.trimmingCharacters(in: .whitespacesAndNewlines), cadence: fromModel.cadence)
    }

    /// The name must come from the sentence, and the cadence must be one the form can show.
    public static func isValid(_ draft: TaskDraft, for sentence: String) -> Bool {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, sentence.range(of: name, options: [.caseInsensitive, .diacriticInsensitive]) != nil else {
            return false
        }
        return draft.cadence?.isSensible ?? true
    }
}

/// Reads a description of the user's week with the model. There are no rules behind it: when the model
/// cannot answer or answers something impossible, the result is nil and the form stays as it was.
public enum RoutineParser {
    public static func routine(
        from description: String,
        instructions: String,
        service: (any LanguageService)?
    ) async -> Routine? {
        guard let routine = try? await service?.routine(instructions: instructions, description: description), isValid(routine) else {
            return nil
        }
        return routine
    }

    public static func isValid(_ routine: Routine) -> Bool {
        func minutes(_ time: DateComponents) -> Int? {
            guard let hour = time.hour, let minute = time.minute, (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
            return hour * 60 + minute
        }
        guard
            let workStart = minutes(routine.workStart),
            let workEnd = minutes(routine.workEnd),
            minutes(routine.wakeTime) != nil,
            minutes(routine.bedtime) != nil
        else {
            return false
        }
        return workStart < workEnd && routine.homeDays.isDisjoint(with: routine.officeDays)
    }
}
