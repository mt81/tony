import Foundation
import MemberwiseInit
import TonyCore
import TonyUIModels

/// Debug builds only: runs the evaluation set on the on-device model and reports the pass rate,
/// and shows what the widget and the background task noted when they tried the model (spike S3).
/// Its text is for developers, so it is in English and not in the String Catalog.
public enum ModelCheckFeature: Feature {
    public struct State: Sendable, Equatable {
        public var cases = EvaluationCase.all
        public var availability: String?
        public var system: String?
        /// What the widget and the background task noted, one line each.
        public var extensionChecks: [String] = []
        public var backgroundCheckRequest: String?
        public var results: [String: EvaluationResult] = [:]
        public var isRunning = false

        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case appeared
        case loaded(availability: String, system: String, extensionChecks: [String])
        case runTapped
        case finished(index: Int, EvaluationResult)
        case backgroundCheckTapped
        case backgroundCheckRequested(String)
    }

    public enum Effect: Sendable, Equatable {
        case load
        case run(index: Int, EvaluationCase)
        case requestBackgroundCheck
    }

    @MemberwiseInit(.public)
    public struct Environment: Sendable {
        public var languageService: any LanguageService
        public var availability: @Sendable () async -> String
        /// The system the report is a baseline for, such as "iOS 27.2 (26B123)".
        public var system: @Sendable () async -> String
        public var extensionChecks: @Sendable () async -> [String]
        /// Asks iOS to run the background check, and says whether iOS took the request.
        public var requestBackgroundCheck: @Sendable () async -> String
    }

    public static func reduce(_ state: inout State, _ action: Action) -> [Effect] {
        switch action {
        case .appeared:
            return [.load]
        case .loaded(let availability, let system, let extensionChecks):
            state.availability = availability
            state.system = system
            state.extensionChecks = extensionChecks
        case .runTapped:
            guard !state.isRunning, let first = state.cases.first else { break }
            state.results = [:]
            state.isRunning = true
            return [.run(index: 0, first)]
        case .finished(let index, let result):
            guard state.cases.indices.contains(index) else { break }
            state.results[state.cases[index].id] = result
            let next = index + 1
            guard state.cases.indices.contains(next) else {
                state.isRunning = false
                break
            }
            return [.run(index: next, state.cases[next])]
        case .backgroundCheckTapped:
            return [.requestBackgroundCheck]
        case .backgroundCheckRequested(let result):
            state.backgroundCheckRequest = result
        }
        return []
    }

    public static func run(_ effect: Effect, in environment: Environment) async -> Action? {
        switch effect {
        case .load:
            return .loaded(
                availability: await environment.availability(),
                system: await environment.system(),
                extensionChecks: await environment.extensionChecks()
            )
        case .run(let index, let evaluationCase):
            return .finished(index: index, await evaluationCase.run(with: environment.languageService))
        case .requestBackgroundCheck:
            return .backgroundCheckRequested(await environment.requestBackgroundCheck())
        }
    }

    @MainActor
    public static func dataModel(
        for state: State,
        context: PresentationContext,
        send: @escaping @MainActor (Action) -> Void
    ) -> ModelCheckScreenDataModel {
        let rows = state.cases.map { evaluationCase -> ModelCheckScreenDataModel.Row in
            guard let result = state.results[evaluationCase.id] else {
                return .init(id: evaluationCase.id, title: evaluationCase.id, input: evaluationCase.input, output: nil, verdict: "not run", hasPassed: nil)
            }
            let seconds = result.duration.secondsText
            return .init(
                id: evaluationCase.id,
                title: evaluationCase.id,
                input: evaluationCase.input,
                output: result.output,
                verdict: result.hasPassed ? "pass · \(seconds)" : "fail · \(seconds) · \(result.problems.joined(separator: "; "))",
                hasPassed: result.hasPassed
            )
        }
        let isComplete = !state.isRunning && state.results.count == state.cases.count

        return ModelCheckScreenDataModel(
            title: "Model check",
            availability: "Model: \(state.availability ?? "checking")",
            run: ButtonDataModel(
                title: state.isRunning ? "Running \(state.results.count + 1) of \(rows.count)" : "Run the evaluation set",
                isEnabled: !state.isRunning,
                accessibilityIdentifier: "runEvaluation",
                action: TonyUIModels.Action(id: "runTapped", parameters: Action.runTapped) { action, _ in send(action) }
            ),
            report: isComplete ? report(state, date: context.now.formatted(Date.ISO8601FormatStyle(timeZone: context.calendar.timeZone).year().month().day())) : nil,
            shareReport: "Share the report",
            rows: rows,
            extensionChecks: state.extensionChecks,
            requestBackgroundCheck: ButtonDataModel(
                title: "Ask iOS for a background check",
                accessibilityIdentifier: "requestBackgroundCheck",
                action: TonyUIModels.Action(id: "backgroundCheckTapped", parameters: Action.backgroundCheckTapped) { action, _ in send(action) }
            ),
            backgroundCheckRequest: state.backgroundCheckRequest,
            onAppear: TonyUIModels.Action(id: "appeared") { _ in send(.appeared) }
        )
    }

    /// The pass rate by group and language, with timings and every failure: what is recorded as the baseline.
    static func report(_ state: State, date: String) -> String {
        var lines = ["Tony model evaluation", "\(state.system ?? "unknown system") · \(date)", ""]
        for group in EvaluationCase.Group.allCases {
            for language in ["en", "fr"] {
                let results = state.cases
                    .filter { $0.group == group && $0.languageCode == language }
                    .compactMap { state.results[$0.id] }
                guard !results.isEmpty else { continue }
                let durations = results.map(\.duration).sorted()
                let passed = results.filter(\.hasPassed).count
                lines.append(
                    "\(group.rawValue) (\(language)): \(passed) of \(results.count) pass · median \(durations[durations.count / 2].secondsText) · slowest \(durations[durations.count - 1].secondsText)"
                )
            }
        }
        let all = state.cases.compactMap { state.results[$0.id] }
        let passed = all.filter(\.hasPassed).count
        let rate = all.isEmpty ? 0 : Int((Double(passed) / Double(all.count) * 100).rounded())
        lines += ["", "Total: \(passed) of \(all.count) pass (\(rate)%)"]

        let failures = state.cases.compactMap { evaluationCase -> String? in
            guard let result = state.results[evaluationCase.id], !result.hasPassed else { return nil }
            return "- \(evaluationCase.id): \(result.problems.joined(separator: "; "))"
        }
        if !failures.isEmpty {
            lines += ["", "Failures:"] + failures
        }
        return lines.joined(separator: "\n")
    }
}
