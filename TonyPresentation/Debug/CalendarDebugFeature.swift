import Foundation
import MemberwiseInit
import TonyCore
import TonyUIModels

/// Debug builds only: asks for calendar access and lists today's blocks, to check the calendar adapter on a device.
/// Its text is for developers, so it is in English and not in the String Catalog.
public enum CalendarDebugFeature: Feature {
    public struct State: Sendable, Equatable {
        public var access: CalendarAccess?
        public var planned: PlannedDay?

        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case appeared
        case requestAccessTapped
        case refreshTapped
        case loaded(access: CalendarAccess, planned: PlannedDay?)
    }

    public enum Effect: Sendable, Equatable {
        case load
        case requestAccess
    }

    @MemberwiseInit(.public)
    public struct Environment: Sendable {
        public var calendarSource: any CalendarSource
        public var coordinator: PlanCoordinator
    }

    public static func reduce(_ state: inout State, _ action: Action) -> [Effect] {
        switch action {
        case .appeared, .refreshTapped:
            return [.load]
        case .requestAccessTapped:
            return [.requestAccess]
        case .loaded(let access, let planned):
            state.access = access
            state.planned = planned
            return []
        }
    }

    public static func run(_ effect: Effect, in environment: Environment) async -> Action? {
        if effect == .requestAccess {
            _ = await environment.calendarSource.requestAccess()
        }
        await environment.coordinator.start()
        return .loaded(access: await environment.calendarSource.access(), planned: await environment.coordinator.current)
    }

    @MainActor
    public static func dataModel(
        for state: State,
        context: PresentationContext,
        send: @escaping @MainActor (Action) -> Void
    ) -> CalendarDebugScreenDataModel {
        let timeStyle = context.timeStyle
        let access =
            switch state.access {
            case .granted: "Calendar access: granted"
            case .denied: "Calendar access: denied (change it in Settings)"
            case .notDetermined: "Calendar access: not asked yet"
            case nil: "Calendar access: checking"
            }

        return CalendarDebugScreenDataModel(
            title: "Calendar check",
            access: access,
            requestAccess: state.access == .notDetermined
                ? ButtonDataModel(title: "Ask for calendar access", accessibilityIdentifier: "requestCalendarAccess") { send(.requestAccessTapped) }
                : nil,
            refresh: ButtonDataModel(title: "Read the calendar again", accessibilityIdentifier: "refreshCalendar") { send(.refreshTapped) },
            plannedAt: state.planned.map { "Read at \($0.plannedAt.formatted(timeStyle))" },
            rows: (state.planned?.context.blocks ?? []).map { block in
                let time = "\(block.interval.start.formatted(timeStyle)) to \(block.interval.end.formatted(timeStyle))"
                let availability =
                    switch block.availability {
                    case .busy: block.eventCount == 1 ? "Busy · 1 event" : "Busy · \(block.eventCount) events merged"
                    case .partiallyAvailable: "Partly available"
                    case .free: "Free"
                    }
                return .init(
                    id: block.interval.start,
                    time: time,
                    detail: "\(availability) · \(block.window.rawValue) · \(block.location.rawValue)",
                    isBusy: block.availability == .busy
                )
            },
            onAppear: { send(.appeared) }
        )
    }
}
