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
        @Guide(description: "The task alone, without how often it repeats, when, where or by when")
        var name: String
        @Guide(description: "One emoji for the task")
        var icon: String
        @Guide(description: "How the task repeats", .anyOf(["never", "interval", "weekdays", "timesPerWeek"]))
        var repeats: String
        @Guide(description: "How many units between two times when it repeats interval, otherwise 0", .range(0...365))
        var intervalCount: Int
        @Guide(description: "The unit of the interval", .anyOf(["day", "week", "month", "year"]))
        var intervalUnit: String
        @Guide(description: "What the interval counts from", .anyOf(["lastTimeDone", "fixedSchedule"]))
        var countedFrom: String
        @Guide(description: "The month of the first time on a fixed schedule, 0 when it does not say", .range(0...12))
        var scheduleMonth: Int
        @Guide(description: "The day of the month of the first time on a fixed schedule, 0 when it does not say", .range(0...31))
        var scheduleDay: Int
        @Guide(description: "Weekdays when it repeats weekdays, otherwise empty", .element(.anyOf(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"])))
        var weekdays: [String]
        @Guide(description: "Times per week when it repeats timesPerWeek, otherwise 0", .range(0...7))
        var timesPerWeek: Int
        @Guide(description: "Where it can be done", .anyOf(["anywhere", "home", "office"]))
        var place: String
        @Guide(description: "The times of day it fits, empty for any time", .element(.anyOf(["morning", "workday", "evening"])))
        var timesOfDay: [String]
        @Guide(description: "The weather it must avoid, empty for any weather", .element(.anyOf(["rain", "snow"])))
        var avoidsWeather: [String]
        @Guide(description: "The steps of a task done in several steps, empty otherwise", .maximumCount(8))
        var subtasks: [SubtaskOutput]
        @Guide(description: "The month of the deadline, 0 when there is none", .range(0...12))
        var deadlineMonth: Int
        @Guide(description: "The day of the month of the deadline, 0 when there is none", .range(0...31))
        var deadlineDay: Int
    }

    @Generable
    struct SubtaskOutput {
        var name: String
        @Guide(description: "How many minutes the step takes", .range(5...480))
        var minutes: Int
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

    func taskReading(instructions: String, sentence: String) async throws -> TaskReading {
        let output = try await session(instructions).respond(to: sentence, generating: TaskOutput.self).content
        let unit = Cadence.Interval.Unit(rawValue: output.intervalUnit) ?? .day
        let cadence: Cadence? =
            switch output.repeats {
            case "interval": .every(output.intervalCount, unit)
            case "weekdays": .weekdays(Self.weekdays(output.weekdays))
            case "timesPerWeek": .timesPerWeek(output.timesPerWeek)
            default: nil
            }
        let requirements = Requirements(
            location: Location(rawValue: output.place),
            windows: Set(output.timesOfDay.compactMap(Window.init(rawValue:))),
            avoidedWeather: Set(output.avoidsWeather.compactMap(WeatherCondition.init(rawValue:)))
        )
        return TaskReading(
            name: output.name,
            icon: output.icon,
            cadence: cadence,
            scheduleStart: output.countedFrom == "fixedSchedule" ? Self.day(month: output.scheduleMonth, day: output.scheduleDay) ?? DateComponents() : nil,
            requirements: requirements,
            subtasks: output.subtasks.map { StepTemplate(name: $0.name, mode: .active, duration: TimeInterval($0.minutes * 60)) },
            deadline: Self.day(month: output.deadlineMonth, day: output.deadlineDay)
        )
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

    /// A day of the month, in a month when there is one; nil when the model gave no day.
    private static func day(month: Int, day: Int) -> DateComponents? {
        guard day > 0 else { return nil }
        return DateComponents(month: month > 0 ? month : nil, day: day)
    }

    private static func time(_ output: TimeOutput) -> DateComponents {
        DateComponents(hour: output.hour, minute: output.minute)
    }
}
