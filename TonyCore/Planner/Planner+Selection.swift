import Foundation

public enum Planner {}

extension Planner {
    public struct Candidate: Sendable, Hashable {
        public var task: TonyTask
        /// The task's steps that were not done today, in order.
        public var remainingSteps: [Step]
        public var score: Double
        /// A task with a deadline is suggested whatever the capacity (D7).
        public var bypassesCap: Bool
    }

    /// The tasks to suggest: every feasible deadline task, then the best-scored others up to the capacity cap.
    public static func select(
        tasks: [TonyTask],
        completions: [Completion],
        context: DayContext,
        now: Date,
        calendar: Calendar,
        configuration: PlannerConfiguration = PlannerConfiguration()
    ) -> [Candidate] {
        let ranked = candidates(
            tasks: tasks,
            completions: completions,
            context: context,
            now: now,
            calendar: calendar,
            configuration: configuration
        )
        let cap = configuration.cap(for: context.capacity)
        return ranked.filter(\.bypassesCap) + ranked.filter { !$0.bypassesCap }.prefix(cap)
    }

    /// Due tasks that fit somewhere in the day, best score first.
    public static func candidates(
        tasks: [TonyTask],
        completions: [Completion],
        context: DayContext,
        now: Date,
        calendar: Calendar,
        configuration: PlannerConfiguration = PlannerConfiguration()
    ) -> [Candidate] {
        let today = completions.filter { calendar.isDate($0.date, inSameDayAs: now) }

        return tasks
            .compactMap { task -> Candidate? in
                let ofTask = today.filter { $0.taskID == task.id }
                let hasDeadline = task.mustHappenBy != nil
                let isDoneToday = ofTask.contains { $0.stepID == nil && $0.outcome == .done }
                let isRefusedToday = ofTask.contains { $0.outcome == .notToday }
                let doneStepIDs = Set(ofTask.filter { $0.outcome == .done }.compactMap(\.stepID))
                let remainingSteps = task.steps.filter { !doneStepIDs.contains($0.id) }

                guard
                    !isDoneToday,
                    !isRefusedToday || hasDeadline,
                    !remainingSteps.isEmpty,
                    task.isDue(completions: completions, on: now, calendar: calendar),
                    remainingSteps.allSatisfy({ step in context.blocks.contains { fits(step, of: task, in: $0, conditions: context.conditions) } })
                else {
                    return nil
                }
                return Candidate(
                    task: task,
                    remainingSteps: remainingSteps,
                    score: score(task, completions: completions, now: now, calendar: calendar, configuration: configuration),
                    bypassesCap: hasDeadline
                )
            }
            .sorted { ($0.score, $1.task.rank, $0.task.id.uuidString) > ($1.score, $0.task.rank, $1.task.id.uuidString) }
    }

    /// Whether the block meets the step's requirements and is long enough for it.
    static func fits(_ step: Step, of task: TonyTask, in block: DayContext.Block, conditions: DayConditions) -> Bool {
        let requirements = task.requirements.merged(with: step.requirements)

        if let location = requirements.location, location != block.location {
            return false
        }
        let allowedWindows: Set<Window> = requirements.windows.isEmpty ? [.morning, .workday, .evening] : requirements.windows
        if !allowedWindows.contains(block.window) {
            return false
        }
        if let weather = conditions.weather, requirements.avoidedWeather.contains(weather) {
            return false
        }
        if requirements.costsMoney && conditions.budgetIsTight {
            return false
        }
        let isAvailable =
            switch block.availability {
            case .free: true
            case .partiallyAvailable: step.mode == .background
            case .busy: false
            }
        return isAvailable && block.interval.duration >= step.duration
    }

    private static func score(
        _ task: TonyTask,
        completions: [Completion],
        now: Date,
        calendar: Calendar,
        configuration: PlannerConfiguration
    ) -> Double {
        let rankScore = 1 / Double(1 + max(task.rank, 0))
        let neglect = min(task.neglect(completions: completions, on: now, calendar: calendar), configuration.maximumNeglect)
        let goalPressure = task.weeklyQuotaProgress(completions: completions, on: now, calendar: calendar)
            .map { Double($0.target - $0.done) / Double(max($0.daysLeft, 1)) } ?? 0

        return configuration.rankWeight * rankScore
            + configuration.neglectWeight * neglect
            + configuration.goalPressureWeight * goalPressure
    }
}

extension Requirements {
    /// A step narrows its task's requirements: its own location and windows win, and the restrictions add up.
    func merged(with step: Requirements) -> Requirements {
        Requirements(
            location: step.location ?? location,
            windows: step.windows.isEmpty ? windows : step.windows,
            avoidedWeather: avoidedWeather.union(step.avoidedWeather),
            costsMoney: costsMoney || step.costsMoney
        )
    }
}
