#if DEBUG
import Foundation
import TonyCore

extension TodayViewModel {
    /// A Today tab on in-memory sources at 8:00 today, for previews. The screen plans it when it appears.
    public static func preview(hasTasks: Bool = true, canAllowCalendar: Bool = false, failure: Bool = false) -> TodayViewModel {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func time(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }
        func step(_ name: String, _ mode: Step.Mode = .active, minutes: Int) -> Step {
            Step(id: UUID(), name: name, mode: mode, duration: TimeInterval(minutes * 60))
        }
        let created = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let plants = TonyTask(id: UUID(), name: "Water the plants", icon: "🪴", kind: .recurring, rank: 0, cadence: .every(5, .day), steps: [step("Water the plants", minutes: 15)], createdAt: created)
        let laundry = TonyTask(
            id: UUID(),
            name: "Laundry",
            icon: "🧺",
            kind: .recurring,
            rank: 1,
            cadence: .every(1, .week),
            steps: [step("Load", minutes: 10), step("Wash", .background, minutes: 45), step("Fold", minutes: 20)],
            createdAt: created
        )
        let gym = TonyTask(
            id: UUID(),
            name: "Gym",
            icon: "🏋️",
            kind: .goal,
            rank: 2,
            cadence: .timesPerWeek(3),
            requirements: Requirements(windows: [.evening]),
            steps: [step("Gym", minutes: 60)],
            createdAt: created
        )
        let lastWatered = calendar.date(byAdding: .day, value: -8, to: today) ?? today
        let repository = PreviewRepository(
            tasks: hasTasks ? [plants, laundry, gym] : [],
            completions: hasTasks ? [Completion(id: UUID(), taskID: plants.id, date: lastWatered, outcome: .done)] : [],
            preferences: [Preference(key: Preference.userNameKey, value: "Matteo", sourceSentence: "", date: .now)]
        )
        let meetings = [0, 20, 40].map { DateInterval(start: time(10, $0), duration: 20 * 60) }
        let now = time(8)
        let coordinator = PlanCoordinator(
            repository: repository,
            calendarSource: PreviewCalendarSource(busy: meetings),
            weatherSource: PreviewWeatherSource(),
            calendar: calendar
        ) { now }
        let access: PermissionStatus = canAllowCalendar ? .notDetermined : .granted
        let store = TodayStore(
            coordinator: coordinator,
            permissions: PermissionStore(providers: [PreviewPermissionProvider(fixedStatus: access)]) {},
            briefingWriter: BriefingWriter(service: nil),
            repository: repository,
            catalog: nil,
            calendar: calendar,
            locale: .current
        )
        if failure {
            store.state.failure = .answer
        }
        return TodayViewModel(store: store, context: PresentationContext(now: now, calendar: calendar, locale: .current))
    }
}
#endif
