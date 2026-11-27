import Foundation
import TonyCore

/// The templated sentences of the Today tab, and the request that asks the on-device model to reword the briefing.
struct TodayWording {
    let planned: PlannedDay?
    /// The name entered in the You tab; nil when there is none.
    let userName: String?
    let context: PresentationContext

    private var timeStyle: Date.FormatStyle {
        context.timeStyle
    }

    /// The meeting blocks that are not over yet.
    var busyBlocks: [DayContext.Block] {
        (planned?.context.blocks ?? []).filter { $0.availability == .busy && $0.interval.end > context.now }
    }

    private var plannedTasks: [TonyTask] {
        var seen: Set<UUID> = []
        return (planned?.plan.items ?? []).compactMap { item in
            seen.insert(item.taskID).inserted ? task(of: item) : nil
        }
    }

    /// The kind of day, its word emphasised.
    var headline: AttributedString {
        let locale = context.locale
        let kind =
            switch plannedTasks.count {
            case 0: localizedAttributed("A free day", locale)
            case 1...2: localizedAttributed("A light day", locale)
            case 3...4: localizedAttributed("A steady day", locale)
            default: localizedAttributed("A full day", locale)
            }
        guard let name = userName else { return kind }
        return localizedAttributed("\(kind), \(name)", locale)
    }

    var briefing: String {
        let locale = context.locale
        let tasks = plannedTasks
        var sentences: [String] = []
        if tasks.isEmpty {
            sentences.append(localized("Nothing needs you today. Enjoy it.", locale))
        } else {
            let names = tasks.map(\.name).formatted(.list(type: .and).locale(locale))
            sentences.append(localized("\(tasks.count) things would be nice today: \(names).", locale))
        }
        let meetings = busyBlocks.reduce(0) { $0 + $1.eventCount }
        if let next = busyBlocks.first {
            sentences.append(localized("You have \(meetings) meetings left today, the next at \(next.interval.start.formatted(timeStyle)).", locale))
        }
        return sentences.joined(separator: " ")
    }

    /// The plan as the model reads it, in the user's language, with the facts its answer is checked against.
    var briefingRequest: BriefingRequest {
        let (calendar, locale) = (context.calendar, context.locale)
        func minutes(_ date: Date) -> Int {
            let time = calendar.dateComponents([.hour, .minute], from: date)
            return (time.hour ?? 0) * 60 + (time.minute ?? 0)
        }
        let planItems = planned?.plan.items ?? []
        let items = planItems.compactMap { item -> BriefingRequest.Item? in
            guard let task = task(of: item), let step = task.steps.first(where: { $0.id == item.stepID }) else { return nil }
            return BriefingRequest.Item(
                time: item.interval.start.formatted(timeStyle),
                title: title(of: step, in: task),
                reason: reason(for: item, step: step, task: task)
            )
        }
        var footer = busyBlocks.map { block in
            localized("Busy from \(block.interval.start.formatted(timeStyle)) to \(block.interval.end.formatted(timeStyle))", locale)
        }
        if items.isEmpty {
            footer.append(localized("Nothing is planned today.", locale))
        }
        let plannedIDs = Set(planItems.map(\.taskID))

        return BriefingRequest(
            instructions: ModelInstructions.briefing(locale),
            header: [context.now.formatted(context.dayStyle)],
            items: items,
            footer: footer,
            allowedMinutes: Set(planItems.map { minutes($0.interval.start) } + busyBlocks.flatMap { [minutes($0.interval.start), minutes($0.interval.end)] }),
            otherTaskNames: (planned?.tasks ?? []).filter { !plannedIDs.contains($0.id) }.map(\.name)
        )
    }

    /// The first item of the plan when it starts within a quarter of an hour: the moment to do it is now.
    var nowItem: DayPlan.Item? {
        guard let item = planned?.plan.items.first, item.interval.start <= context.now.addingTimeInterval(15 * 60) else {
            return nil
        }
        return item
    }

    /// The tasks already done today, in the order they were done.
    var done: String? {
        let calendar = context.calendar
        let tasks = planned?.tasks ?? []
        var seen: Set<UUID> = []
        let names = (planned?.completions ?? [])
            .filter { $0.stepID == nil && $0.outcome == .done && calendar.isDate($0.date, inSameDayAs: context.now) }
            .sorted { $0.date < $1.date }
            .compactMap { completion in
                seen.insert(completion.taskID).inserted ? tasks.first { $0.id == completion.taskID }?.name : nil
            }
        guard !names.isEmpty else {
            return nil
        }
        let list = names.formatted(.list(type: .and).locale(context.locale))
        return localized("Good job, today you already did \(list).", context.locale)
    }

    func task(of item: DayPlan.Item) -> TonyTask? {
        planned?.tasks.first { $0.id == item.taskID }
    }

    func title(of step: Step, in task: TonyTask) -> String {
        task.steps.count > 1 ? "\(task.name) · \(step.name)" : task.name
    }

    func isNeglected(_ task: TonyTask) -> Bool {
        task.neglect(completions: planned?.completions ?? [], on: context.now, calendar: context.calendar) > 0
    }

    func reason(for item: DayPlan.Item, step: Step, task: TonyTask) -> String {
        let locale = context.locale
        if isNeglected(task), let days = daysSinceLastDone(task) {
            return localized("\(days) days since last time", locale)
        }
        let nextMeetings = busyBlocks.first { $0.interval.start >= item.interval.start }
        let placement =
            switch item.reason {
            case .beforeBlock:
                nextMeetings.map { localized("Before your \($0.interval.start.formatted(timeStyle)) meetings.", locale) }
                    ?? localized("The first moment that fits.", locale)
            case .afterBlock: localized("Right after your meetings.", locale)
            case .needsEvening: localized("Kept for the evening.", locale)
            case .earliestFit: localized("The first moment that fits.", locale)
            }
        return step.mode == .background ? "\(placement) \(localized("It runs on its own.", locale))" : placement
    }

    func meetingsDetail(for block: DayContext.Block) -> String {
        localized("until \(block.interval.end.formatted(timeStyle))", context.locale)
    }

    func tileDetail(for task: TonyTask) -> String {
        let (now, calendar, locale) = (context.now, context.calendar, context.locale)
        let completions = planned?.completions ?? []
        if let progress = task.weeklyQuotaProgress(completions: completions, on: now, calendar: calendar) {
            return localized("\(progress.done) of \(progress.target) this week", locale)
        }
        if daysSinceLastDone(task) == 0 {
            return localized("Done today", locale)
        }
        if isNeglected(task), let days = daysSinceLastDone(task) {
            return localized("\(days) days since last time", locale)
        }
        return TaskSummary(task: task, completions: completions, context: context).status
    }

    private func daysSinceLastDone(_ task: TonyTask) -> Int? {
        let calendar = context.calendar
        let lastDone = (planned?.completions ?? [])
            .filter { $0.taskID == task.id && $0.stepID == nil && $0.outcome == .done }
            .map(\.date)
            .max()
        return lastDone.flatMap {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: context.now)).day
        }
    }
}
