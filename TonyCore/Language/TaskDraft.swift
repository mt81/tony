import Foundation
import MemberwiseInit

/// A task as read from one sentence. It fills the task form; nothing is saved before the user confirms.
@MemberwiseInit(.public)
public struct TaskDraft: Sendable, Hashable {
    public var name: String
    /// One emoji; nil when the sentence gave none.
    public var icon: String? = nil
    public var cadence: Cadence?
    public var requirements: Requirements = Requirements()
    /// The parts of a task done in several steps, in order; empty for a task done in one go.
    public var subtasks: [StepTemplate] = []
    public var deadline: Date? = nil

    public var kind: TonyTask.Kind {
        TonyTask.Kind(cadence: cadence)
    }
}

/// What the model read in a sentence, before it is checked and dated.
@MemberwiseInit(.public)
public struct TaskReading: Sendable, Hashable {
    public var name: String
    public var icon: String = ""
    /// An interval here counts from the last time it was done; `scheduleStart` makes it a fixed schedule.
    public var cadence: Cadence? = nil
    /// The first day of a fixed schedule, as calendar fields ("the 1st", "1 March"); nil when it counts from the last time.
    public var scheduleStart: DateComponents? = nil
    public var requirements: Requirements = Requirements()
    public var subtasks: [StepTemplate] = []
    /// The day it must happen by, as calendar fields; nil when it has none.
    public var deadline: DateComponents? = nil
}

extension TonyTask.Kind {
    /// A number of times a week is a goal, another cadence a recurring task, and no cadence a one-time task.
    public init(cadence: Cadence?) {
        switch cadence {
        case .timesPerWeek: self = .goal
        case .interval, .weekdays: self = .recurring
        case nil: self = .oneTime
        }
    }
}

/// Reads a sentence as a task. The rules read the cadence; the model reads everything else, and the cadence when the rules find none.
/// What the model answers is checked, and the rules' draft stands when it cannot answer or answers something the form cannot show.
public enum TaskSentenceParser {
    public static func draft(
        from sentence: String,
        locale: Locale,
        instructions: String,
        service: (any LanguageService)?,
        now: Date,
        calendar: Calendar
    ) async -> TaskDraft {
        let byRules = CadenceRules.draft(from: sentence, locale: locale)
        guard
            let reading = try? await service?.taskReading(instructions: instructions, sentence: sentence),
            isValid(reading, for: sentence)
        else {
            return byRules
        }
        let today = calendar.startOfDay(for: now)
        var cadence = byRules.cadence ?? reading.cadence
        if case .interval(let interval, .lastCompletion) = cadence,
           let scheduleStart = reading.scheduleStart,
           let start = firstDay(matching: scheduleStart, onOrAfter: today, calendar: calendar) {
            cadence = .interval(interval, countedFrom: .schedule(from: start))
        }
        var requirements = reading.requirements
        requirements.costsMoney = false
        let subtasks = reading.subtasks.filter(isSensible)

        return TaskDraft(
            name: reading.name.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: emoji(reading.icon),
            cadence: cadence,
            requirements: requirements,
            subtasks: subtasks.count > 1 ? subtasks : [],
            deadline: reading.deadline.flatMap { firstDay(matching: $0, onOrAfter: today, calendar: calendar) }
        )
    }

    /// The name must come from the sentence, and the cadence must be one the form can show.
    public static func isValid(_ reading: TaskReading, for sentence: String) -> Bool {
        let name = reading.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, sentence.range(of: name, options: [.caseInsensitive, .diacriticInsensitive]) != nil else {
            return false
        }
        return reading.cadence?.isSensible ?? true
    }

    /// The first day from `day` whose fields match; `day` itself when there are none.
    static func firstDay(matching fields: DateComponents, onOrAfter day: Date, calendar: Calendar) -> Date? {
        var fields = fields
        fields.calendar = nil
        fields.timeZone = nil
        let isEmpty = fields.month == nil && fields.day == nil && fields.weekday == nil
        if isEmpty || calendar.date(day, matchesComponents: fields) {
            return day
        }
        return calendar.nextDate(after: day, matching: fields, matchingPolicy: .previousTimePreservingSmallerComponents)
            .map { calendar.startOfDay(for: $0) }
    }

    private static func isSensible(_ subtask: StepTemplate) -> Bool {
        !subtask.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (5 * 60...8 * 3600).contains(subtask.duration)
    }

    private static func emoji(_ text: String) -> String? {
        guard let first = text.trimmingCharacters(in: .whitespaces).first,
              first.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) else {
            return nil
        }
        return String(first)
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
