import Foundation
import Synchronization
import Testing
import TonyCore
import TonyUIModels
@testable import TonyPresentation

/// Answers every case the way its expectations want, except the cases whose id is listed.
private struct ObedientService: LanguageService {
    var failing: Set<String> = []

    private func evaluationCase(input: String) throws -> EvaluationCase {
        let found = EvaluationCase.all.first { evaluationCase in
            switch evaluationCase.kind {
            case .briefing(let request): request.prompt() == input
            case .task(let sentence, _, _): sentence == input
            case .routine(let description, _): input.hasSuffix(description)
            }
        }
        guard let found, !failing.contains(found.id) else { throw CocoaError(.featureUnsupported) }
        return found
    }

    func briefing(instructions: String, plan: String) async throws -> String {
        guard case .briefing(let request) = try evaluationCase(input: plan).kind else { return "" }
        return request.items.isEmpty ? "Nothing needs you today." : request.items.map(\.title).joined(separator: ", ")
    }

    func taskReading(instructions: String, sentence: String) async throws -> TaskReading {
        guard case .task(_, _, let cadence) = try evaluationCase(input: sentence).kind else { return TaskReading(name: "") }
        return TaskReading(name: sentence, cadence: cadence)
    }

    func routine(instructions: String, description: String) async throws -> Routine {
        guard case .routine(_, let expected) = try evaluationCase(input: description).kind else { return .standard }
        var routine = Routine.standard
        routine.homeDays = expected.homeDays ?? routine.homeDays
        routine.officeDays = expected.officeDays ?? routine.officeDays
        routine.workStart = expected.workStart ?? routine.workStart
        routine.workEnd = expected.workEnd ?? routine.workEnd
        routine.wakeTime = expected.wakeTime ?? routine.wakeTime
        routine.bedtime = expected.bedtime ?? routine.bedtime
        return routine
    }
}

@MainActor
private func store(failing: Set<String> = []) -> Store<ModelCheckFeature> {
    Store(
        state: ModelCheckFeature.State(),
        environment: ModelCheckFeature.Environment(
            languageService: ObedientService(failing: failing),
            availability: { "available" },
            system: { "iOS 27.2 · iPhone" },
            extensionChecks: { ["Widget: has not run yet"] },
            requestBackgroundCheck: { "requested" }
        )
    )
}

// MARK: The set

@Test func theSetHasTwentySixCasesPerLanguageWithTheSameShape() {
    let english = EvaluationCase.all.filter { $0.languageCode == "en" }
    let french = EvaluationCase.all.filter { $0.languageCode == "fr" }

    #expect(english.count == 26)
    #expect(french.count == 26)
    #expect(english.map(\.group) == french.map(\.group))
    #expect(Set(EvaluationCase.all.map(\.id)).count == 52)
    #expect(english.filter { $0.group == .briefing }.count == 10)
    #expect(english.filter { $0.group == .task }.count == 12)
    #expect(english.filter { $0.group == .routine }.count == 4)
}

@Test func everyPlanFitsTheBudget() throws {
    for evaluationCase in EvaluationCase.all {
        guard case .briefing(let request) = evaluationCase.kind else { continue }

        #expect(request.prompt().count <= BriefingRequest.characterBudget, "\(evaluationCase.id)")
    }
    let firstFrench = try #require(EvaluationCase.all.first { $0.id == "B1 fr" })
    #expect(firstFrench.input.hasPrefix("mardi 10 novembre\n08:00 Arroser les plantes. Le premier moment qui convient."))
    #expect(firstFrench.input.hasSuffix("Occupé de 14:00 à 15:30"))
}

// MARK: Checks

@Test func aBriefingIsCheckedLikeInTheApp() async throws {
    struct Inventing: LanguageService {
        func briefing(instructions: String, plan: String) async throws -> String { "Water the plants at 9:15, then vacuum." }
        func taskReading(instructions: String, sentence: String) async throws -> TaskReading { TaskReading(name: "Feed the cat", cadence: .timesPerWeek(2)) }
        func routine(instructions: String, description: String) async throws -> Routine {
            var routine = Routine.standard
            routine.workEnd = DateComponents(hour: 6, minute: 0)
            return routine
        }
    }
    let briefing = try #require(EvaluationCase.all.first { $0.id == "B1 en" })
    let task = try #require(EvaluationCase.all.first { $0.id == "T1 en" })
    let routine = try #require(EvaluationCase.all.first { $0.id == "R2 en" })

    #expect(await briefing.run(with: Inventing()).problems == ["unknownTime(minutes: 555)", "unplannedTask(\"Vacuum\")"])
    #expect(await task.run(with: Inventing()).problems == [
        "the app would drop this answer",
        "name has no \"plants\"",
        "cadence is not \(Cadence.every(5, .day))",
    ])
    #expect(await routine.run(with: Inventing()).problems == ["the app would drop this answer", "work start is wrong", "work end is wrong"])
}

// MARK: Runner

@MainActor
@Test func runningTheSetGivesAReportWithPassRatesAndFailures() async throws {
    let store = store(failing: ["B2 fr", "T3 en"])
    let context = try Sample.context()

    store.send(.appeared)
    store.send(.runTapped)
    #expect(store.dataModel(context: context).report == nil)
    #expect(!store.dataModel(context: context).run.isEnabled)
    await store.waitForEffects()
    let model = store.dataModel(context: context)
    let report = try #require(model.report).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    #expect(model.run.isEnabled)
    #expect(model.rows.count == 52)
    #expect(model.rows.first?.verdict.hasPrefix("pass · 0.00 s") == true)
    #expect(report[0] == "Tony model evaluation")
    #expect(report[1] == "iOS 27.2 · iPhone · 2026-11-10")
    #expect(report[3].hasPrefix("Briefings (en): 10 of 10 pass · median 0.00 s"))
    #expect(report[4].hasPrefix("Briefings (fr): 9 of 10 pass"))
    #expect(report[5].hasPrefix("Tasks (en): 11 of 12 pass"))
    #expect(report[8].hasPrefix("Routines (fr): 4 of 4 pass"))
    #expect(report[10] == "Total: 50 of 52 pass (96%)")
    #expect(Array(report[12...]).count == 3)
    #expect(report[12] == "Failures:")
    #expect(report[13].hasPrefix("- T3 en: no answer:"))
    #expect(report[14].hasPrefix("- B2 fr: no answer:"))
}

@MainActor
@Test func theScreenShowsWhatTheExtensionsNotedAndTheBackgroundRequest() async throws {
    let store = store()

    store.send(.appeared)
    store.send(.backgroundCheckTapped)
    await store.waitForEffects()
    let model = store.dataModel(context: try Sample.context())

    #expect(model.availability == "Model: available")
    #expect(model.extensionChecks == ["Widget: has not run yet"])
    #expect(model.backgroundCheckRequest == "requested")
    #expect(model.rows.first?.verdict == "not run")
}
