import Foundation
import Testing
import TonyCore
import TonyUIModels
@testable import TonyPresentation

private func spikeCase(_ id: String) throws -> ModelSpikeCase {
    try #require(ModelSpikeCase.all.first { $0.id == id })
}

private func answer(_ output: ModelSpikeAnswer.Output, seconds: Double = 1) -> ModelSpikeAnswer {
    ModelSpikeAnswer(output: output, duration: .seconds(seconds))
}

// MARK: Checks

@Test func aBriefingThatNamesEveryTaskAndOnlyPlanTimesPasses() throws {
    let full = try spikeCase("S1 full day (en)")
    let text = "Start with the plants at 8, the laundry can run from 12:30 and the gym waits until 6 pm. Your meetings are at 10:00."

    #expect(full.problems(with: answer(.briefing(text))).isEmpty)
}

@Test func aBriefingIsRejectedForAnInventedTimeAMissingTaskOrASlowAnswer() throws {
    let full = try spikeCase("S1 full day (en)")
    let text = "Water the plants at 8:00, then do the laundry at 9:15."

    #expect(full.problems(with: answer(.briefing(text), seconds: 4)) == [
        "does not name gym",
        "names 9:15, which is not in the plan",
        "slower than 3.00 s",
    ])
}

@Test func frenchTimesAreReadToo() {
    #expect(ModelSpikeCase.minutesOfDay(in: "À 8 h les plantes, à 12h30 la lessive, à 18:00 le sport.") == [480, 750, 1080])
}

@Test(arguments: [
    (output: ModelSpikeAnswer.Output.task(name: "Water the plants", cadence: .afterCompletion(days: 5)), problems: [String]()),
    (output: .task(name: "Water", cadence: .afterCompletion(days: 5)), problems: ["name has no \"plants\""]),
    (output: .task(name: "Water the plants", cadence: .timesPerWeek(5)), problems: ["cadence is not afterCompletion(days: 5)"]),
    (output: .failure("guardrail"), problems: ["failed: guardrail"]),
    (output: .briefing("Water the plants"), problems: ["answered with the wrong kind of output"]),
])
func aParsedTaskMustMatchTheNameAndTheCadence(output: ModelSpikeAnswer.Output, problems: [String]) throws {
    #expect(try spikeCase("S2 every N days (en)").problems(with: answer(output)) == problems)
}

@Test func everyCaseExistsInBothLanguages() {
    let english = ModelSpikeCase.all.filter { $0.languageCode == "en" }
    let french = ModelSpikeCase.all.filter { $0.languageCode == "fr" }

    #expect(english.count == french.count)
    #expect(english.map { $0.id.replacingOccurrences(of: "(en)", with: "(fr)") } == french.map(\.id))
}

// MARK: Feature

@MainActor
@Test func runningAsksTheModelForEachCaseInTurnAndShowsTheVerdicts() async throws {
    let environment = ModelSpikeFeature.Environment(
        availability: { "available" },
        respond: { spikeCase in
            switch spikeCase.kind {
            case .briefing: answer(.failure("no model"))
            case .parsing(let keyword, let cadence): answer(.task(name: keyword, cadence: cadence), seconds: 0.5)
            }
        },
        extensionChecks: { ["Widget: never ran"] },
        requestBackgroundCheck: { "requested" }
    )
    let store = Store<ModelSpikeFeature>(state: ModelSpikeFeature.State(), environment: environment)
    let context = try Sample.context()

    store.send(.appeared)
    store.send(.runTapped)
    store.send(.backgroundCheckTapped)
    await store.waitForEffects()
    let model = store.dataModel(context: context)

    #expect(model.availability == "Model: available")
    #expect(model.extensionChecks == ["Widget: never ran"])
    #expect(model.backgroundCheckRequest == "requested")
    #expect(model.summary == "8 of 12 pass · done")
    #expect(model.run.isEnabled)
    #expect(model.rows.first?.verdict == "fail · 1.00 s · failed: no model")
    #expect(model.rows.last?.verdict == "pass · 0.50 s")
    #expect(model.rows.last?.output == "passeport · no cadence")
}
