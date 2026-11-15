import Foundation
import TonyCore
import TonyUIModels

/// The Today tab: the day's plan from the coordinator, and the user's answers to it.
public enum TodayFeature: Feature {
    /// Parts of the screen that are mocked until the chunk that owns them:
    /// the consistency week (C25), the briefing question (C22, C24), the user's name (C13),
    /// and meeting titles, which the calendar adapter does not read (privacy rule: busy times only).
    public struct Mocked: Sendable, Equatable {
        public enum DayScore: Sendable, Equatable {
            case score(done: Int, suggested: Int)
            case rest
        }

        public enum Question: Sendable, Equatable {
            case lunchPlanned
        }

        public var userName: String
        /// One entry per day, from the first day of the week.
        public var week: [DayScore]
        public var question: Question?
        public var meetingTitles: [String]

        public static let sample = Mocked(
            userName: "Matteo",
            week: [
                .score(done: 4, suggested: 5),
                .rest,
                .score(done: 1, suggested: 3),
                .score(done: 3, suggested: 4),
                .score(done: 2, suggested: 2),
                .rest,
                .score(done: 2, suggested: 3),
            ],
            question: .lunchPlanned,
            meetingTitles: ["Daily scrum", "Weekly sync", "Planning review"]
        )
    }

    public struct State: Sendable, Equatable {
        public var planned: PlannedDay?
        public var mocked: Mocked?
        public var hasFailed = false

        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case appeared
        /// The coordinator's latest plan; nil while there is none.
        case planned(PlannedDay?)
        case checkTapped(DayPlan.Item)
        case laterTapped(DayPlan.Item)
        case notTodayTapped(DayPlan.Item)
        case questionAnswered
        case failed
        case alertDismissed
    }

    public enum Effect: Sendable, Equatable {
        case plan
        case record(PlanAction, on: DayPlan.Item)
    }

    public struct Environment: Sendable {
        public var coordinator: PlanCoordinator

        public init(coordinator: PlanCoordinator) {
            self.coordinator = coordinator
        }
    }

    public static func reduce(_ state: inout State, _ action: Action) -> [Effect] {
        switch action {
        case .appeared:
            if state.mocked == nil {
                state.mocked = .sample
            }
            return [.plan]
        case .planned(let planned):
            state.planned = planned ?? state.planned
        case .checkTapped(let item):
            return [.record(.done, on: item)]
        case .laterTapped(let item):
            return [.record(.later, on: item)]
        case .notTodayTapped(let item):
            return [.record(.notToday, on: item)]
        case .questionAnswered:
            state.mocked?.question = nil
        case .failed:
            state.hasFailed = true
        case .alertDismissed:
            state.hasFailed = false
        }
        return []
    }

    public static func run(_ effect: Effect, in environment: Environment) async -> Action? {
        let coordinator = environment.coordinator
        switch effect {
        case .plan:
            await coordinator.start()
        case .record(let action, let item):
            do {
                try await coordinator.record(action, on: item)
            } catch {
                return .failed
            }
        }
        return .planned(await coordinator.current)
    }
}
