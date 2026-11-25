import Foundation
import MemberwiseInit
import TonyCore
import TonyUIModels

/// Debug builds only: asks for calendar access, saves a city for the weather, and shows today's weather and blocks,
/// to check the calendar and weather adapters on a device. The city picker stands in for the location screen (#68).
/// Its text is for developers, so it is in English and not in the String Catalog.
public enum CalendarDebugFeature: Feature {
    public struct State: Sendable, Equatable {
        public var access: CalendarAccess?
        public var planned: PlannedDay?
        public var place: Place?

        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case appeared
        case requestAccessTapped
        case refreshTapped
        case placeChosen(Place?)
        case loaded(access: CalendarAccess, planned: PlannedDay?, place: Place?)
    }

    public enum Effect: Sendable, Equatable {
        case load
        case requestAccess
        case savePlace(Place?)
    }

    static let sampleCities = [
        Place(name: "Paris", latitude: 48.86, longitude: 2.35),
        Place(name: "Toronto", latitude: 43.65, longitude: -79.38),
        Place(name: "Oslo", latitude: 59.91, longitude: 10.75),
    ]

    @MemberwiseInit(.public)
    public struct Environment: Sendable {
        public var calendarSource: any CalendarSource
        public var repository: any Repository
        public var coordinator: PlanCoordinator
    }

    public static func reduce(_ state: inout State, _ action: Action) -> [Effect] {
        switch action {
        case .appeared, .refreshTapped:
            return [.load]
        case .requestAccessTapped:
            return [.requestAccess]
        case .placeChosen(let place):
            return [.savePlace(place)]
        case .loaded(let access, let planned, let place):
            state.access = access
            state.planned = planned
            state.place = place
            return []
        }
    }

    public static func run(_ effect: Effect, in environment: Environment) async -> Action? {
        switch effect {
        case .load:
            break
        case .requestAccess:
            _ = await environment.calendarSource.requestAccess()
        case .savePlace(let place):
            var routine = (try? await environment.repository.routine()) ?? .standard
            routine.place = place
            try? await environment.repository.save(routine)
        }
        await environment.coordinator.start()
        return .loaded(
            access: await environment.calendarSource.access(),
            planned: await environment.coordinator.current,
            place: (try? await environment.repository.routine())?.place
        )
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
        let weather =
            switch (state.planned, state.place) {
            case (nil, _): "Weather: checking"
            case (_, nil): "Weather: no city saved"
            case (let planned?, let place?):
                planned.context.conditions.weather.map { "Weather today in \(place.name): \($0.rawValue)" }
                    ?? "Weather in \(place.name): not read (no task needs some weather, or no forecast)"
            }
        let places = sampleCities.map { place in
            ButtonDataModel(
                title: "Use \(place.name)",
                accessibilityIdentifier: "place\(place.name)",
                action: TonyUIModels.Action(id: "placeChosen", parameters: Action.placeChosen(place)) { action, _ in send(action) }
            )
        } + [
            ButtonDataModel(
                title: "Clear the city",
                accessibilityIdentifier: "clearPlace",
                action: TonyUIModels.Action(id: "placeChosen", parameters: Action.placeChosen(nil)) { action, _ in send(action) }
            )
        ]

        return CalendarDebugScreenDataModel(
            title: "Calendar check",
            access: access,
            weather: weather,
            places: places,
            requestAccess: state.access == .notDetermined
                ? ButtonDataModel(
                    title: "Ask for calendar access",
                    accessibilityIdentifier: "requestCalendarAccess",
                    action: TonyUIModels.Action(id: "requestAccessTapped", parameters: Action.requestAccessTapped) { action, _ in send(action) }
                )
                : nil,
            refresh: ButtonDataModel(
                title: "Read the calendar again",
                accessibilityIdentifier: "refreshCalendar",
                action: TonyUIModels.Action(id: "refreshTapped", parameters: Action.refreshTapped) { action, _ in send(action) }
            ),
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
            onAppear: TonyUIModels.Action(id: "appeared") { _ in send(.appeared) }
        )
    }
}
