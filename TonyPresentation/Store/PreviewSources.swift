#if DEBUG
import Foundation
import TonyCore

/// Keeps what previews save, in memory. Previews only: tests have their own fakes.
actor PreviewRepository: Repository {
    private var storedRoutine: Routine?
    private var storedPreferences: [Preference]

    init(routine: Routine? = nil, preferences: [Preference] = []) {
        storedRoutine = routine
        storedPreferences = preferences
    }

    func tasks() -> [TonyTask] { [] }
    func save(_ task: TonyTask) {}
    func deleteTask(id: UUID) {}
    func reorderTasks(_ orderedIDs: [UUID]) {}
    func completions() -> [Completion] { [] }
    func save(_ completion: Completion) {}
    func routine() -> Routine? { storedRoutine }
    func save(_ routine: Routine) { storedRoutine = routine }
    func preferences() -> [Preference] { storedPreferences }
    func save(_ preference: Preference) {
        storedPreferences.removeAll { $0.key == preference.key }
        storedPreferences.append(preference)
    }
}

/// A calendar with no events, whose access is fixed. Previews only.
struct PreviewCalendarSource: CalendarSource {
    var fixedAccess: CalendarAccess

    func access() -> CalendarAccess { fixedAccess }
    func requestAccess() -> CalendarAccess { fixedAccess }
    func busyIntervals(in interval: DateInterval) -> [DateInterval] { [] }
    func changes() -> AsyncStream<Void> { AsyncStream { _ in } }
}

/// No forecast, as when the weather cannot be read. Previews only.
struct PreviewWeatherSource: WeatherSource {
    func condition(on day: Date, at place: Place) -> WeatherCondition? { nil }
}
#endif
