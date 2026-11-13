import Foundation

extension Planner {
    /// Plans the rest of the day from `now`. Nothing is placed before `now`, and steps done today are not placed again.
    public static func plan(
        tasks: [TonyTask],
        completions: [Completion],
        context: DayContext,
        now: Date,
        calendar: Calendar,
        configuration: PlannerConfiguration = PlannerConfiguration()
    ) -> DayPlan {
        let remainingContext = context.remaining(from: now)
        let selected = select(
            tasks: tasks,
            completions: completions,
            context: remainingContext,
            now: now,
            calendar: calendar,
            configuration: configuration
        )
        let today = completions.filter { calendar.isDate($0.date, inSameDayAs: now) }

        var items: [DayPlan.Item] = []
        var occupied: [DateInterval] = []
        for candidate in selected {
            let placed = place(
                candidate,
                completions: today.filter { $0.taskID == candidate.task.id },
                context: context,
                remainingContext: remainingContext,
                occupied: occupied,
                now: now
            )
            let activeStepIDs = Set(candidate.task.steps.filter { $0.mode == .active }.map(\.id))
            occupied += placed.filter { activeStepIDs.contains($0.stepID) }.map(\.interval)
            items += placed
        }
        return DayPlan(items: items.sorted { ($0.interval.start, $0.stepID.uuidString) < ($1.interval.start, $1.stepID.uuidString) })
    }

    /// The completions to record when the user answers an item. Plan again with them to get the new day.
    public static func completions(for action: PlanAction, on item: DayPlan.Item, of task: TonyTask, at now: Date) -> [Completion] {
        switch action {
        case .done:
            let stepDone = Completion(id: UUID(), taskID: task.id, stepID: item.stepID, date: now, outcome: .done)
            let taskDone = Completion(id: UUID(), taskID: task.id, date: now, outcome: .done)
            return item.stepID == task.steps.last?.id ? [stepDone, taskDone] : [stepDone]
        case .later:
            return [Completion(id: UUID(), taskID: task.id, stepID: item.stepID, date: now, outcome: .later)]
        case .notToday:
            return [Completion(id: UUID(), taskID: task.id, date: now, outcome: .notToday)]
        }
    }

    /// Places every remaining step of one task, or none of them when they cannot all fit in order.
    private static func place(
        _ candidate: Candidate,
        completions: [Completion],
        context: DayContext,
        remainingContext: DayContext,
        occupied: [DateInterval],
        now: Date
    ) -> [DayPlan.Item] {
        let task = candidate.task
        let steps = candidate.remainingSteps

        func slots(for step: Step) -> [DateInterval] {
            remainingContext.blocks
                .filter { fits(step, of: task, in: $0, conditions: context.conditions) }
                .flatMap { step.mode == .active ? $0.interval.subtracting(occupied) : [$0.interval] }
                .filter { $0.duration >= step.duration }
        }

        // Backward: the latest start of each step that leaves room for the steps after it.
        var latestStarts: [UUID: Date] = [:]
        var bound = Date.distantFuture
        for (index, step) in steps.enumerated().reversed() {
            let latestStart = slots(for: step)
                .compactMap { slot -> Date? in
                    let start = min(slot.end, bound).addingTimeInterval(-step.duration)
                    return start >= slot.start ? start : nil
                }
                .max()
            guard let latestStart else { return [] }
            latestStarts[step.id] = latestStart
            if index > 0 {
                bound = latestStart.addingTimeInterval(-steps[index - 1].minimumGapToNextStep)
            }
        }

        // Forward: each step at its earliest fit, after the step before it has finished.
        var items: [DayPlan.Item] = []
        var cursor = now
        for step in task.steps {
            if let done = completions.last(where: { $0.stepID == step.id && $0.outcome == .done }) {
                let runsOnItsOwn = step.mode == .background ? step.duration : 0
                cursor = max(cursor, done.date.addingTimeInterval(runsOnItsOwn + step.minimumGapToNextStep))
                continue
            }
            guard steps.contains(step), let latestStart = latestStarts[step.id] else { continue }

            let postponedUntil = completions
                .last { $0.stepID == step.id && $0.outcome == .later }
                .flatMap { later in context.blocks.first { $0.interval.start <= later.date && later.date < $0.interval.end } }
                .map(\.interval.end)
            let notBefore = max(cursor, postponedUntil ?? cursor)
            let start = slots(for: step)
                .compactMap { slot -> Date? in
                    let start = max(slot.start, notBefore)
                    return start.addingTimeInterval(step.duration) <= slot.end ? start : nil
                }
                .min()
            guard let start, start <= latestStart else { return [] }

            let interval = DateInterval(start: start, duration: step.duration)
            items.append(
                DayPlan.Item(
                    taskID: task.id,
                    stepID: step.id,
                    interval: interval,
                    latestStart: latestStart,
                    reason: reason(for: step, of: task, at: interval, in: context)
                )
            )
            cursor = interval.end.addingTimeInterval(step.minimumGapToNextStep)
        }
        return items
    }

    private static func reason(for step: Step, of task: TonyTask, at interval: DateInterval, in context: DayContext) -> DayPlan.Reason {
        if task.requirements.merged(with: step.requirements).windows == [.evening] {
            return .needsEvening
        }
        let busyBlocks = context.blocks.filter { $0.availability == .busy }
        if busyBlocks.contains(where: { $0.interval.end == interval.start }) {
            return .afterBlock
        }
        let containingBlock = context.blocks.first { $0.interval.start <= interval.start && interval.start < $0.interval.end }
        if let containingBlock, busyBlocks.contains(where: { $0.interval.start == containingBlock.interval.end }) {
            return .beforeBlock
        }
        return .earliestFit
    }
}

extension DayContext {
    /// The same day with everything before `now` cut off.
    func remaining(from now: Date) -> DayContext {
        var remaining = self
        remaining.blocks = blocks.compactMap { block in
            guard block.interval.end > now else { return nil }
            var block = block
            block.interval = DateInterval(start: max(block.interval.start, now), end: block.interval.end)
            return block
        }
        return remaining
    }
}

extension DateInterval {
    /// The parts of this interval that none of the others cover, in order.
    func subtracting(_ others: [DateInterval]) -> [DateInterval] {
        var parts: [DateInterval] = []
        var cursor = start
        for other in others.sorted(by: { $0.start < $1.start }) where other.end > cursor && other.start < end {
            if other.start > cursor {
                parts.append(DateInterval(start: cursor, end: other.start))
            }
            cursor = max(cursor, other.end)
        }
        if cursor < end {
            parts.append(DateInterval(start: cursor, end: end))
        }
        return parts
    }
}
