import EventKit
import TonyCore

/// Full access to the user's calendars, which Tony needs to read when they are busy.
actor EventKitCalendarPermission: PermissionProvider {
    nonisolated let permission = Permission.calendar
    private let store = EKEventStore()

    static var currentStatus: PermissionStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func status() -> PermissionStatus {
        Self.currentStatus
    }

    func request() async -> PermissionStatus {
        guard Self.currentStatus == .notDetermined else { return Self.currentStatus }
        let isGranted = (try? await store.requestFullAccessToEvents()) ?? false
        return isGranted ? .granted : .denied
    }
}
