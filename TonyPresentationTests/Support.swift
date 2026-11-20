import Foundation
import Synchronization
import Testing
import TonyCore
@testable import TonyPresentation

enum Sample {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Day 2 is Monday 2 November 2026.
    static func november(_ day: Int, hour: Int = 12) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour)))
    }

    static func context(day: Int = 10, language: String = "en") throws -> PresentationContext {
        PresentationContext(now: try november(day), calendar: calendar, locale: Locale(identifier: language))
    }

    static func identifier(_ number: Int) throws -> UUID {
        try #require(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number)))
    }

    static func task(
        _ number: Int,
        _ name: String,
        kind: TonyTask.Kind = .recurring,
        cadence: Cadence? = .every(5, .day),
        mustHappenBy: Date? = nil
    ) throws -> TonyTask {
        TonyTask(
            id: try identifier(number),
            name: name,
            icon: "⭐️",
            kind: kind,
            rank: number,
            cadence: cadence,
            steps: [Step(id: try identifier(number * 100), name: name, mode: .active, duration: 30 * 60)],
            mustHappenBy: mustHappenBy,
            createdAt: try november(1)
        )
    }

    static func done(_ task: TonyTask, day: Int) throws -> Completion {
        Completion(id: UUID(), taskID: task.id, date: try november(day), outcome: .done)
    }
}

/// Keeps what the feature sends, so a test can tap a data model and see the action.
@MainActor
final class SentActions<Action> {
    private(set) var actions: [Action] = []

    func send(_ action: Action) {
        actions.append(action)
    }
}

actor FakeRepository: Repository {
    private var storedTasks: [TonyTask]
    private var storedCompletions: [Completion] = []
    private(set) var savedTasks: [TonyTask] = []
    private(set) var reorders: [[UUID]] = []
    var failsOnSave = false

    init(tasks: [TonyTask] = []) {
        storedTasks = tasks
    }

    func setFailsOnSave(_ fails: Bool) {
        failsOnSave = fails
    }

    func tasks() -> [TonyTask] { storedTasks }

    func save(_ task: TonyTask) throws {
        if failsOnSave { throw CocoaError(.fileWriteUnknown) }
        savedTasks.append(task)
        if let index = storedTasks.firstIndex(where: { $0.id == task.id }) {
            storedTasks[index] = task
        } else {
            storedTasks.append(task)
        }
    }

    func deleteTask(id: UUID) {
        storedTasks.removeAll { $0.id == id }
    }

    func reorderTasks(_ orderedIDs: [UUID]) {
        reorders.append(orderedIDs)
    }

    func completions() -> [Completion] { storedCompletions }
    func save(_ completion: Completion) throws {
        if failsOnSave { throw CocoaError(.fileWriteUnknown) }
        storedCompletions.append(completion)
    }
    private var storedRoutine: Routine?
    private var storedPreferences: [Preference] = []

    func routine() -> Routine? { storedRoutine }
    func save(_ routine: Routine) throws {
        if failsOnSave { throw CocoaError(.fileWriteUnknown) }
        storedRoutine = routine
    }
    func preferences() -> [Preference] { storedPreferences }
    func save(_ preference: Preference) {
        storedPreferences.removeAll { $0.key == preference.key }
        storedPreferences.append(preference)
    }
}

struct FakeCatalog: TaskCatalog {
    func steps(forTaskNamed name: String, locale: Locale) -> [StepTemplate]? {
        guard name.localizedCaseInsensitiveContains("laundry") else { return nil }
        return [
            StepTemplate(name: "Load", mode: .active, duration: 600),
            StepTemplate(name: "Wash", mode: .background, duration: 2700),
        ]
    }
}

struct FakeCalendarSource: CalendarSource {
    var busyIntervals: [DateInterval] = []

    func access() -> CalendarAccess { .granted }
    func requestAccess() -> CalendarAccess { .granted }
    func busyIntervals(in interval: DateInterval) -> [DateInterval] { busyIntervals }
    func changes() -> AsyncStream<Void> { AsyncStream { _ in } }
}

/// Always gives the same forecast; none by default.
struct FakeWeatherSource: WeatherSource {
    var forecast: WeatherCondition?

    func condition(on day: Date) -> WeatherCondition? { forecast }
}

final class TestClock: Sendable {
    private let date: Mutex<Date>

    init(_ date: Date) {
        self.date = Mutex(date)
    }

    var now: Date { date.withLock { $0 } }

    func set(_ newDate: Date) {
        date.withLock { $0 = newDate }
    }
}

/// A calendar the user has not answered for yet, and who says yes when asked.
actor UnansweredCalendarSource: CalendarSource {
    private var current = CalendarAccess.notDetermined

    func access() -> CalendarAccess { current }
    func requestAccess() -> CalendarAccess {
        current = .granted
        return current
    }
    func busyIntervals(in interval: DateInterval) -> [DateInterval] { [] }
    nonisolated func changes() -> AsyncStream<Void> { AsyncStream { _ in } }
}

/// A language model that always gives the same briefing, and keeps what it was asked.
final class FakeLanguageService: LanguageService {
    private let answer: String
    private let reading: TaskReading?
    private let readRoutine: Routine?
    private let asked = Mutex<[(instructions: String, plan: String)]>([])

    init(briefing: String = "", reading: TaskReading? = nil, routine: Routine? = nil) {
        answer = briefing
        self.reading = reading
        readRoutine = routine
    }

    func taskReading(instructions: String, sentence: String) throws -> TaskReading {
        asked.withLock { $0.append((instructions, sentence)) }
        guard let reading else { throw CocoaError(.featureUnsupported) }
        return reading
    }

    func routine(instructions: String, description: String) throws -> Routine {
        asked.withLock { $0.append((instructions, description)) }
        guard let readRoutine else { throw CocoaError(.featureUnsupported) }
        return readRoutine
    }

    var requests: [(instructions: String, plan: String)] { asked.withLock { $0 } }

    func briefing(instructions: String, plan: String) -> String {
        asked.withLock { $0.append((instructions, plan)) }
        return answer
    }
}
