#if DEBUG
import Foundation
import TonyCore

/// Keeps what previews save, in memory. Previews only: tests have their own fakes.
actor PreviewRepository: Repository {
    private var storedTasks: [TonyTask]
    private var storedCompletions: [Completion]
    private var storedRoutine: Routine?
    private var storedPreferences: [Preference]

    init(tasks: [TonyTask] = [], completions: [Completion] = [], routine: Routine? = nil, preferences: [Preference] = []) {
        storedTasks = tasks
        storedCompletions = completions
        storedRoutine = routine
        storedPreferences = preferences
    }

    func tasks() -> [TonyTask] { storedTasks }
    func save(_ task: TonyTask) {
        storedTasks.removeAll { $0.id == task.id }
        storedTasks.append(task)
    }
    func deleteTask(id: UUID) { storedTasks.removeAll { $0.id == id } }
    func reorderTasks(_ orderedIDs: [UUID]) {}
    func completions() -> [Completion] { storedCompletions }
    func save(_ completion: Completion) { storedCompletions.append(completion) }
    func routine() -> Routine? { storedRoutine }
    func save(_ routine: Routine) { storedRoutine = routine }
    func preferences() -> [Preference] { storedPreferences }
    func save(_ preference: Preference) {
        storedPreferences.removeAll { $0.key == preference.key }
        storedPreferences.append(preference)
    }
}

/// A calendar with fixed busy times, none by default. Previews only.
struct PreviewCalendarSource: CalendarSource {
    var busy: [DateInterval] = []

    func busyIntervals(in interval: DateInterval) -> [DateInterval] { busy }
    func changes() -> AsyncStream<Void> { AsyncStream { _ in } }
}

/// No forecast, as when the weather cannot be read. Previews only.
struct PreviewWeatherSource: WeatherSource {
    func condition(on day: Date, at place: Place) -> WeatherCondition? { nil }
}

/// Calendar access that stays as it is, whatever is asked. Previews only.
struct PreviewPermissionProvider: PermissionProvider {
    var fixedStatus: PermissionStatus

    var permission: Permission { .calendar }
    func status() -> PermissionStatus { fixedStatus }
    func request() -> PermissionStatus { fixedStatus }
}
#endif
