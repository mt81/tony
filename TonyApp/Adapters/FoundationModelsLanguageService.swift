import Foundation
import FoundationModels
import TonyCore

/// The on-device model through Foundation Models. Each call is one short session with typed output and no history.
struct FoundationModelsLanguageService: LanguageService {
    @Generable
    struct BriefingText {
        var text: String
    }

    @Generable
    struct TaskOutput {
        @Guide(description: "The task alone, without how often it repeats")
        var name: String
        @Guide(description: "How the task repeats", .anyOf(["everyNDays", "onWeekdays", "timesPerWeek", "once"]))
        var repeats: String
        @Guide(description: "Days between two times when it repeats everyNDays, otherwise 0", .range(0...365))
        var days: Int
        @Guide(description: "Weekdays when it repeats onWeekdays, otherwise empty", .element(.anyOf(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"])))
        var weekdays: [String]
        @Guide(description: "Times per week when it repeats timesPerWeek, otherwise 0", .range(0...7))
        var timesPerWeek: Int
    }

    @Generable
    struct RoutineOutput {
        @Guide(description: "The weekdays worked at home", .element(.anyOf(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"])))
        var homeDays: [String]
        @Guide(description: "The weekdays worked at the office", .element(.anyOf(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"])))
        var officeDays: [String]
        var workStart: TimeOutput
        var workEnd: TimeOutput
        var wakeTime: TimeOutput
        var bedtime: TimeOutput
    }

    @Generable
    struct TimeOutput {
        @Guide(description: "The hour, on the 24-hour clock", .range(0...23))
        var hour: Int
        @Guide(description: "The minutes past the hour", .range(0...59))
        var minute: Int
    }

    enum Failure: Error {
        case modelUnavailable
    }

    func briefing(instructions: String, plan: String) async throws -> String {
        try await session(instructions).respond(to: plan, generating: BriefingText.self).content.text
    }

    func taskDraft(instructions: String, sentence: String) async throws -> TaskDraft {
        let output = try await session(instructions).respond(to: sentence, generating: TaskOutput.self).content
        let cadence: Cadence? =
            switch output.repeats {
            case "everyNDays": .afterCompletion(days: output.days)
            case "onWeekdays": .weekdays(Self.weekdays(output.weekdays))
            case "timesPerWeek": .timesPerWeek(output.timesPerWeek)
            default: nil
            }
        return TaskDraft(name: output.name, cadence: cadence)
    }

    func routine(instructions: String, description: String) async throws -> Routine {
        let output = try await session(instructions).respond(to: description, generating: RoutineOutput.self).content
        return Routine(
            homeDays: Self.weekdays(output.homeDays),
            officeDays: Self.weekdays(output.officeDays),
            workStart: Self.time(output.workStart),
            workEnd: Self.time(output.workEnd),
            wakeTime: Self.time(output.wakeTime),
            bedtime: Self.time(output.bedtime)
        )
    }

    private func session(_ instructions: String) throws -> LanguageModelSession {
        guard SystemLanguageModel.default.isAvailable else { throw Failure.modelUnavailable }
        return LanguageModelSession(instructions: instructions)
    }

    private static func weekdays(_ names: [String]) -> Set<Locale.Weekday> {
        let weekdays: [String: Locale.Weekday] = [
            "monday": .monday, "tuesday": .tuesday, "wednesday": .wednesday, "thursday": .thursday,
            "friday": .friday, "saturday": .saturday, "sunday": .sunday,
        ]
        return Set(names.compactMap { weekdays[$0.lowercased()] })
    }

    private static func time(_ output: TimeOutput) -> DateComponents {
        DateComponents(hour: output.hour, minute: output.minute)
    }
}
