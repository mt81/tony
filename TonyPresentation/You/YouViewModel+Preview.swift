#if DEBUG
import Foundation
import TonyCore

extension YouViewModel {
    /// A You tab on in-memory sources, for previews.
    public static func preview(name: String = "Matteo", canAllowCalendar: Bool = true, isEditing: Bool = false) -> YouViewModel {
        var routine = Routine.standard
        routine.homeDays = [.monday, .wednesday, .friday]
        routine.officeDays = [.tuesday, .thursday]
        routine.workEnd = DateComponents(hour: 17, minute: 30)
        let access: PermissionStatus = canAllowCalendar ? .notDetermined : .granted
        let repository = PreviewRepository(
            routine: routine,
            preferences: name.isEmpty ? [] : [Preference(key: Preference.userNameKey, value: name, sourceSentence: "", date: .now)]
        )
        let store = YouStore(
            repository: repository,
            permissions: PermissionStore(providers: [PreviewPermissionProvider(fixedStatus: access)]) {},
            coordinator: PlanCoordinator(repository: repository, calendarSource: PreviewCalendarSource(), weatherSource: PreviewWeatherSource(), calendar: .current) { .now },
            calendar: .current,
            locale: .current,
            now: { .now }
        )
        store.state.name = name
        store.state.routine = routine
        store.state.calendarAccess = access
        if isEditing {
            store.startEditing()
        }
        return YouViewModel(store: store, context: PresentationContext(now: .now, calendar: .current, locale: .current))
    }
}
#endif
