#if DEBUG
import Foundation
import TonyCore

extension PermissionViewModel {
    /// The permission sheet for the calendar, for previews.
    public static func preview(isRefused: Bool = false) -> PermissionViewModel {
        let store = PermissionStore(providers: [PreviewPermissionProvider(fixedStatus: isRefused ? .denied : .notDetermined)]) {}
        store.state.permission = .calendar
        store.state.statuses[.calendar] = isRefused ? .denied : .notDetermined
        store.state.isAsking = true
        return PermissionViewModel(store: store, context: PresentationContext(now: .now, calendar: .current, locale: .current))
    }
}
#endif
