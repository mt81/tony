#if DEBUG
import BackgroundTasks
import Foundation
import FoundationModels
import TonyCore
import TonyPresentation

/// Debug builds only: answers the model spike cases with the on-device model (S1, S2).
enum ModelSpikeRunner {
    @Generable
    struct Briefing {
        @Guide(description: "Two to four short, warm sentences about the day")
        var text: String
    }

    @Generable
    struct TaskDraft {
        @Guide(description: "The task alone, without how often it repeats")
        var name: String
        @Guide(description: "How the task repeats", .anyOf(["everyNDays", "onWeekdays", "timesPerWeek", "once"]))
        var cadence: String
        @Guide(description: "Days between two times when cadence is everyNDays, otherwise 0", .range(0...365))
        var days: Int
        @Guide(description: "English weekday names when cadence is onWeekdays, otherwise empty")
        var weekdays: [String]
        @Guide(description: "Times per week when cadence is timesPerWeek, otherwise 0", .range(0...7))
        var timesPerWeek: Int
    }

    static var environment: ModelSpikeFeature.Environment {
        ModelSpikeFeature.Environment(
            availability: { ModelExtensionCheck.availability },
            respond: { await respond(to: $0) },
            extensionChecks: { ModelExtensionCheck.lastResults() },
            requestBackgroundCheck: {
                do {
                    try await BGTaskScheduler.shared.submitTaskRequest(BGAppRefreshTaskRequest(identifier: ModelExtensionCheck.backgroundTaskIdentifier))
                    return "Requested. iOS decides when it runs; come back to this screen later."
                } catch {
                    return "iOS refused the request: \(error.localizedDescription)"
                }
            }
        )
    }

    static func respond(to spikeCase: ModelSpikeCase) async -> ModelSpikeAnswer {
        let language = Locale(identifier: "en").localizedString(forLanguageCode: spikeCase.languageCode) ?? spikeCase.languageCode
        let start = ContinuousClock.now
        let output: ModelSpikeAnswer.Output
        do {
            switch spikeCase.kind {
            case .briefing:
                let session = LanguageModelSession(
                    instructions: """
                        You are Tony, a calm assistant who tells someone about their day. \
                        Write in \(language). Use only the tasks and times of the plan you are given. \
                        Never add a task, a time or a meeting.
                        """
                )
                let response = try await session.respond(to: spikeCase.input, generating: Briefing.self)
                output = .briefing(response.content.text)
            case .parsing:
                let session = LanguageModelSession(
                    instructions: """
                        You turn one sentence, written in \(language), into a task for a to-do app. \
                        Keep the name in \(language).
                        """
                )
                let draft = try await session.respond(to: spikeCase.input, generating: TaskDraft.self).content
                output = .task(name: draft.name, cadence: cadence(of: draft))
            }
        } catch {
            output = .failure(error.localizedDescription)
        }
        return ModelSpikeAnswer(output: output, duration: ContinuousClock.now - start)
    }

    private static func cadence(of draft: TaskDraft) -> Cadence? {
        switch draft.cadence {
        case "everyNDays": .afterCompletion(days: draft.days)
        case "onWeekdays": .weekdays(Set(draft.weekdays.compactMap { Locale.Weekday(englishName: $0) }))
        case "timesPerWeek": .timesPerWeek(draft.timesPerWeek)
        default: nil
        }
    }
}

extension Locale.Weekday {
    fileprivate init?(englishName: String) {
        let weekdays: [String: Locale.Weekday] = [
            "monday": .monday, "tuesday": .tuesday, "wednesday": .wednesday, "thursday": .thursday,
            "friday": .friday, "saturday": .saturday, "sunday": .sunday,
        ]
        guard let weekday = weekdays[englishName.lowercased()] else { return nil }
        self = weekday
    }
}
#endif
