import EventKit
import TonyCore

/// The user's calendars through EventKit, including feeds they subscribed to in the Calendar app.
actor EventKitCalendarSource: CalendarSource {
    private let store = EKEventStore()

    func access() -> CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func requestAccess() async -> CalendarAccess {
        guard access() == .notDetermined else { return access() }
        let isGranted = (try? await store.requestFullAccessToEvents()) ?? false
        return isGranted ? .granted : .denied
    }

    func busyIntervals(in interval: DateInterval) -> [DateInterval] {
        guard access() == .granted else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        return store.events(matching: predicate)
            .map(CalendarEvent.init)
            .busyIntervals(in: interval)
    }

    nonisolated func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let listening = Task {
                for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged).map({ _ in }) {
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in listening.cancel() }
        }
    }
}

extension CalendarEvent {
    /// Reads only the times and the status of an event, never its title, place or people.
    fileprivate init(_ event: EKEvent) {
        let showsAs: ShowsAs =
            switch event.availability {
            case .free: .free
            case .tentative: .tentative
            case .unavailable: .unavailable
            default: .busy
            }
        let ownAnswer = event.attendees?.first(where: \.isCurrentUser)?.participantStatus
        self.init(
            interval: DateInterval(start: event.startDate, end: max(event.endDate, event.startDate)),
            isAllDay: event.isAllDay,
            showsAs: showsAs,
            isCancelled: event.status == .canceled,
            isDeclined: ownAnswer == .declined
        )
    }
}
