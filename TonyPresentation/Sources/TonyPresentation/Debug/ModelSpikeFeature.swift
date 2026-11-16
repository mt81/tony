import Foundation
import TonyCore
import TonyUIModels

/// Debug builds only: runs the model spikes (S1 briefing, S2 parsing, S3 widget and background task) and shows the results.
/// Its text is for developers, so it is in English and not in the String Catalog.
public enum ModelSpikeFeature: Feature {
    public struct State: Sendable, Equatable {
        public var cases = ModelSpikeCase.all
        public var availability: String?
        /// What the widget and the background task noted, one line each.
        public var extensionChecks: [String] = []
        public var backgroundCheckRequest: String?
        public var answers: [String: ModelSpikeAnswer] = [:]
        public var isRunning = false

        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case appeared
        case loaded(availability: String, extensionChecks: [String])
        case runTapped
        case answered(index: Int, ModelSpikeAnswer)
        case backgroundCheckTapped
        case backgroundCheckRequested(String)
    }

    public enum Effect: Sendable, Equatable {
        case load
        case respond(index: Int, ModelSpikeCase)
        case requestBackgroundCheck
    }

    public struct Environment: Sendable {
        public var availability: @Sendable () async -> String
        public var respond: @Sendable (ModelSpikeCase) async -> ModelSpikeAnswer
        public var extensionChecks: @Sendable () async -> [String]
        /// Asks iOS to run the background check, and says whether iOS took the request.
        public var requestBackgroundCheck: @Sendable () async -> String

        public init(
            availability: @escaping @Sendable () async -> String,
            respond: @escaping @Sendable (ModelSpikeCase) async -> ModelSpikeAnswer,
            extensionChecks: @escaping @Sendable () async -> [String],
            requestBackgroundCheck: @escaping @Sendable () async -> String
        ) {
            self.availability = availability
            self.respond = respond
            self.extensionChecks = extensionChecks
            self.requestBackgroundCheck = requestBackgroundCheck
        }
    }

    public static func reduce(_ state: inout State, _ action: Action) -> [Effect] {
        switch action {
        case .appeared:
            return [.load]
        case .loaded(let availability, let extensionChecks):
            state.availability = availability
            state.extensionChecks = extensionChecks
        case .runTapped:
            guard !state.isRunning, let first = state.cases.first else { break }
            state.answers = [:]
            state.isRunning = true
            return [.respond(index: 0, first)]
        case .answered(let index, let answer):
            guard state.cases.indices.contains(index) else { break }
            state.answers[state.cases[index].id] = answer
            let next = index + 1
            guard state.cases.indices.contains(next) else {
                state.isRunning = false
                break
            }
            return [.respond(index: next, state.cases[next])]
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
            return .loaded(availability: await environment.availability(), extensionChecks: await environment.extensionChecks())
        case .respond(let index, let spikeCase):
            return .answered(index: index, await environment.respond(spikeCase))
        case .requestBackgroundCheck:
            return .backgroundCheckRequested(await environment.requestBackgroundCheck())
        }
    }

    @MainActor
    public static func dataModel(
        for state: State,
        context: PresentationContext,
        send: @escaping @MainActor (Action) -> Void
    ) -> ModelSpikeScreenDataModel {
        let rows = state.cases.map { spikeCase -> ModelSpikeScreenDataModel.Row in
            guard let answer = state.answers[spikeCase.id] else {
                return .init(id: spikeCase.id, title: spikeCase.id, input: spikeCase.input, output: nil, verdict: "not run", hasPassed: nil)
            }
            let problems = spikeCase.problems(with: answer)
            let output =
                switch answer.output {
                case .briefing(let text): text
                case .task(let name, let cadence): "\(name) · \(cadence.map { "\($0)" } ?? "no cadence")"
                case .failure(let message): message
                }
            let seconds = answer.duration.secondsText
            return .init(
                id: spikeCase.id,
                title: spikeCase.id,
                input: spikeCase.input,
                output: output,
                verdict: problems.isEmpty ? "pass · \(seconds)" : "fail · \(seconds) · \(problems.joined(separator: "; "))",
                hasPassed: problems.isEmpty
            )
        }
        let passed = rows.filter { $0.hasPassed == true }.count
        let answered = rows.filter { $0.hasPassed != nil }.count

        return ModelSpikeScreenDataModel(
            title: "Model check",
            availability: "Model: \(state.availability ?? "checking")",
            run: ButtonDataModel(
                title: state.isRunning ? "Running \(answered + 1) of \(rows.count)" : "Run the prompts",
                isEnabled: !state.isRunning,
                accessibilityIdentifier: "runModelSpikes"
            ) { send(.runTapped) },
            summary: answered == 0 ? nil : "\(passed) of \(answered) pass\(state.isRunning ? "" : " · done")",
            rows: rows,
            extensionChecks: state.extensionChecks,
            requestBackgroundCheck: ButtonDataModel(title: "Ask iOS for a background check", accessibilityIdentifier: "requestBackgroundCheck") {
                send(.backgroundCheckTapped)
            },
            backgroundCheckRequest: state.backgroundCheckRequest,
            onAppear: { send(.appeared) }
        )
    }
}
