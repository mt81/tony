import Foundation

/// A day as it was last planned, with everything a screen needs to show it.
public struct PlannedDay: Sendable, Hashable {
    public var plannedAt: Date
    public var context: DayContext
    public var plan: DayPlan
    public var tasks: [TonyTask]
    public var completions: [Completion]
}

extension Routine {
    /// Used until the user has entered their own: up at 7:00, work at home 9:00 to 17:00 on weekdays, bed at 23:00.
    public static let standard = Routine(
        homeDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
        officeDays: [],
        workStart: DateComponents(hour: 9, minute: 0),
        workEnd: DateComponents(hour: 17, minute: 0),
        wakeTime: DateComponents(hour: 7, minute: 0),
        bedtime: DateComponents(hour: 23, minute: 0)
    )
}

/// The one place that plans the day: it loads the tasks, builds the day's context, runs the planner and publishes the result.
/// It plans again when something is recorded, the status changes, the calendar changes, or the app comes back.
public actor PlanCoordinator {
    private let repository: any Repository
    private let calendarSource: any CalendarSource
    private let weatherSource: any WeatherSource
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let configuration: PlannerConfiguration

    /// The latest plan; nil until the first one is ready.
    public private(set) var current: PlannedDay?

    private var status: (day: Date, value: DayStatus)?
    private var needsPlan = false
    private var planning: Task<Void, Never>?
    private var listening: Task<Void, Never>?
    private var subscribers: [UUID: AsyncStream<PlannedDay>.Continuation] = [:]

    public init(
        repository: any Repository,
        calendarSource: any CalendarSource,
        weatherSource: any WeatherSource,
        calendar: Calendar,
        configuration: PlannerConfiguration = PlannerConfiguration(),
        now: @escaping @Sendable () -> Date
    ) {
        self.repository = repository
        self.calendarSource = calendarSource
        self.weatherSource = weatherSource
        self.calendar = calendar
        self.configuration = configuration
        self.now = now
    }

    /// Plans the day and starts following calendar changes.
    public func start() async {
        if listening == nil {
            let changes = calendarSource.changes()
            listening = Task { [weak self] in
                for await _ in changes {
                    await self?.replan()
                }
            }
        }
        await replan()
    }

    /// The latest plan right away, if there is one, then every new plan.
    public func plans() -> AsyncStream<PlannedDay> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: PlannedDay.self, bufferingPolicy: .bufferingNewest(1))
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        if let current {
            continuation.yield(current)
        }
        return stream
    }

    /// Call when the app comes to the foreground: time has passed, so the rest of the day is planned again.
    public func refresh() async {
        await replan()
    }

    /// Sets how the user is today. It lasts until the end of the day.
    public func setStatus(_ status: DayStatus) async {
        self.status = (calendar.startOfDay(for: now()), status)
        await replan()
    }

    /// Records the user's answer to a planned item, then plans again.
    public func record(_ action: PlanAction, on item: DayPlan.Item) async throws {
        guard let task = current?.tasks.first(where: { $0.id == item.taskID }) else { return }
        for completion in Planner.completions(for: action, on: item, of: task, at: now()) {
            try await repository.save(completion)
        }
        await replan()
    }

    /// Returns once a plan that includes the caller's change is published.
    /// Requests that arrive while a plan is being made share one more pass, however many they are.
    private func replan() async {
        needsPlan = true
        if planning == nil {
            planning = Task {
                while needsPlan {
                    needsPlan = false
                    await planOnce()
                }
                planning = nil
            }
        }
        await planning?.value
    }

    /// Keeps the previous plan when the tasks cannot be read.
    private func planOnce() async {
        let now = now()
        let today = calendar.startOfDay(for: now)
        guard
            let tasks = try? await repository.tasks(),
            let completions = try? await repository.completions()
        else {
            return
        }
        let routine = (try? await repository.routine()) ?? .standard
        let dayInterval = calendar.dateInterval(of: .day, for: now) ?? DateInterval(start: today, duration: 86_400)
        let busyIntervals = (try? await calendarSource.busyIntervals(in: dayInterval)) ?? []
        let weather: WeatherCondition? =
            if let place = routine.place, tasks.contains(where: \.avoidsWeather) {
                await weatherSource.condition(on: now, at: place)
            } else {
                nil
            }

        let context = DayContext(
            routine: routine,
            busyIntervals: busyIntervals,
            status: status?.day == today ? status?.value ?? .normal : .normal,
            conditions: DayConditions(weather: weather),
            day: now,
            calendar: calendar
        )
        let plan = Planner.plan(
            tasks: tasks,
            completions: completions,
            context: context,
            now: now,
            calendar: calendar,
            configuration: configuration
        )
        let planned = PlannedDay(plannedAt: now, context: context, plan: plan, tasks: tasks, completions: completions)
        current = planned
        for subscriber in subscribers.values {
            subscriber.yield(planned)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }
}

extension TonyTask {
    /// Whether the task, or one of its steps, should not be done in some weather: only then is the weather read.
    fileprivate var avoidsWeather: Bool {
        !requirements.avoidedWeather.isEmpty || steps.contains { !$0.requirements.avoidedWeather.isEmpty }
    }
}
