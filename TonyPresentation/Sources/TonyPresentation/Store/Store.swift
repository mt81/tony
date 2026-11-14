import Foundation
import Observation

/// A screen's logic: what it holds, what can happen to it, the work that happens outside it, and what it shows.
public protocol Feature: Sendable {
    associatedtype State: Sendable
    associatedtype Action: Sendable
    associatedtype Effect: Sendable
    associatedtype Environment: Sendable
    associatedtype DataModel

    /// Applies an action to the state and returns the side effects it asks for. Pure: no clock, no storage, no network.
    static func reduce(_ state: inout State, _ action: Action) -> [Effect]
    /// Does one side effect and returns the action that reports its result, if any.
    static func run(_ effect: Effect, in environment: Environment) async -> Action?
    /// What the screen shows for this state. Every user action goes back through `send`.
    @MainActor
    static func dataModel(for state: State, context: PresentationContext, send: @escaping @MainActor (Action) -> Void) -> DataModel
    /// Effects with the same key replace each other: starting one cancels the one before.
    static func cancellationKey(for effect: Effect) -> String?
}

extension Feature {
    public static func cancellationKey(for effect: Effect) -> String? {
        nil
    }
}

/// What a data model is drawn for: the moment, and how dates, numbers and words are shown.
public struct PresentationContext: Sendable {
    public var now: Date
    public var calendar: Calendar
    public var locale: Locale

    public init(now: Date, calendar: Calendar, locale: Locale) {
        self.now = now
        self.calendar = calendar
        self.locale = locale
    }
}

/// Holds a feature's state. Actions change it through the reducer; views redraw from the data model it gives.
@MainActor
@Observable
public final class Store<F: Feature> {
    public private(set) var state: F.State

    @ObservationIgnored private let environment: F.Environment
    @ObservationIgnored private var running: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var runningByKey: [String: UUID] = [:]

    public init(state: F.State, environment: F.Environment) {
        self.state = state
        self.environment = environment
    }

    public func send(_ action: F.Action) {
        for effect in F.reduce(&state, action) {
            start(effect)
        }
    }

    public func dataModel(context: PresentationContext) -> F.DataModel {
        F.dataModel(for: state, context: context) { [weak self] action in
            self?.send(action)
        }
    }

    /// Waits until every running effect has finished, including the ones they lead to.
    func waitForEffects() async {
        while let task = running.values.first {
            await task.value
        }
    }

    private func start(_ effect: F.Effect) {
        let id = UUID()
        let key = F.cancellationKey(for: effect)
        if let key, let previous = runningByKey[key] {
            running[previous]?.cancel()
        }
        running[id] = Task { [environment] in
            let action = await F.run(effect, in: environment)
            self.running[id] = nil
            if let key, self.runningByKey[key] == id {
                self.runningByKey[key] = nil
            }
            if !Task.isCancelled, let action {
                self.send(action)
            }
        }
        if let key {
            runningByKey[key] = id
        }
    }
}
