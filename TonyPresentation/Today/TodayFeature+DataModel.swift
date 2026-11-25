import Foundation
import TonyCore
import TonyUIModels

extension TodayFeature {
    @MainActor
    public static func dataModel(
        for state: State,
        context: PresentationContext,
        send: @escaping @MainActor (Action) -> Void
    ) -> TodayScreenDataModel {
        let locale = context.locale
        let wording = TodayWording(state: state, context: context)

        return TodayScreenDataModel(
            date: context.now.formatted(context.dayStyle),
            headline: wording.headline,
            briefing: state.briefing.flatMap { $0.plan == state.planned?.plan ? $0.text : nil } ?? wording.briefing,
            calendar: calendar(state: state, locale: locale, send: send),
            timelineTitle: localized("Your day", locale),
            timeline: timeline(state: state, wording: wording, send: send),
            tilesTitle: localized("How things are", locale),
            tiles: tiles(state: state, wording: wording),
            editor: state.editor.map { editor in
                TaskEditor.dataModel(
                    for: editor,
                    context: context,
                    edit: { send(.editor($0)) },
                    cancel: TonyUIModels.Action(id: "editorCancelled", parameters: Action.editorCancelled) { action, _ in send(action) },
                    save: TonyUIModels.Action(id: "editorSaved", parameters: Action.editorSaved) { action, _ in send(action) },
                    delete: TonyUIModels.Action(id: "nothing") { _ in }
                )
            },
            dismissEditor: TonyUIModels.Action(id: "editorCancelled") { _ in send(.editorCancelled) },
            alert: state.failure.map { failure in
                let title =
                    switch failure {
                    case .answer: localized("Your answer could not be saved", locale)
                    case .task: localized("Your tasks could not be saved", locale)
                    }
                return AlertDataModel(title: title, dismiss: ButtonDataModel(title: localized("OK", locale), action: TonyUIModels.Action(id: "alertDismissed", parameters: Action.alertDismissed) { action, _ in send(action) }))
            },
            onAppear: TonyUIModels.Action(id: "appeared") { _ in send(.appeared) }
        )
    }

    @MainActor
    private static func calendar(state: State, locale: Locale, send: @escaping @MainActor (Action) -> Void) -> CalendarCardDataModel? {
        guard let access = state.calendarAccess, access != .granted else { return nil }
        return CalendarCardDataModel(
            title: localized("Calendar", locale),
            text: localized("Tony doesn’t see your calendar yet, so he can’t plan around your meetings.", locale),
            allow: ButtonDataModel(
                title: localized("Plan around my events", locale),
                accessibilityIdentifier: "planAroundEvents",
                action: TonyUIModels.Action(id: "planAroundEventsTapped", parameters: Action.planAroundEventsTapped) { action, _ in send(action) }
            )
        )
    }

    @MainActor
    private static func timeline(
        state: State,
        wording: TodayWording,
        send: @escaping @MainActor (Action) -> Void
    ) -> [TodayScreenDataModel.TimelineEntry] {
        let locale = wording.context.locale
        let items = state.planned?.plan.items ?? []
        let firstItemID = items.first?.id
        let nowItemID = wording.nowItem?.id

        var entries: [(start: Date, entry: TodayScreenDataModel.TimelineEntry)] = []
        for item in items {
            guard let task = wording.task(of: item), let step = task.steps.first(where: { $0.id == item.stepID }) else { continue }
            let title = wording.title(of: step, in: task)
            var actions: [ButtonDataModel] = []
            if item.id == firstItemID {
                actions.append(
                    ButtonDataModel(
                        title: localized("Later", locale),
                        accessibilityIdentifier: "today-later",
                        action: TonyUIModels.Action(id: "laterTapped", parameters: Action.laterTapped(item)) { action, _ in send(action) }
                    )
                )
                if task.mustHappenBy == nil {
                    actions.append(
                        ButtonDataModel(
                            title: localized("Not today", locale),
                            accessibilityIdentifier: "today-notToday",
                            action: TonyUIModels.Action(id: "notTodayTapped", parameters: Action.notTodayTapped(item)) { action, _ in send(action) }
                        )
                    )
                }
            }
            let time = item.interval.start.formatted(wording.context.timeStyle)
            let taskItem = TimelineItemDataModel.TaskItem(
                icon: task.icon,
                time: time,
                title: title,
                reason: wording.reason(for: item, step: step, task: task),
                actions: actions,
                check: ButtonDataModel(
                    title: localized("Mark \(title) as done", locale),
                    accessibilityIdentifier: "today-check-\(title)",
                    action: TonyUIModels.Action(id: "checkTapped", parameters: Action.checkTapped(item)) { action, _ in send(action) }
                ),
                isNeglected: wording.isNeglected(task),
                now: item.id == nowItemID ? localized("\(time) · a good moment to start", locale) : nil,
                accessibilityIdentifier: "today-item-\(title)"
            )
            entries.append((item.interval.start, .init(id: item.stepID.uuidString, item: .task(taskItem, isLast: false))))
        }
        for block in wording.busyBlocks {
            let start = block.interval.start
            let item = TimelineItemDataModel.meetings(
                time: start.formatted(wording.context.timeStyle),
                title: localized("\(block.eventCount) meetings, back to back", locale),
                detail: wording.meetingsDetail(for: block)
            )
            entries.append((start, .init(id: "meetings-\(start.timeIntervalSinceReferenceDate)", item: item)))
        }

        var timeline: [TodayScreenDataModel.TimelineEntry] = []
        if let done = wording.done {
            timeline.append(.init(id: "done", item: .done(text: done)))
        }
        if nowItemID == nil {
            timeline.append(.init(id: "now", item: .now(text: localized("Now", locale))))
        }
        timeline += entries.sorted { $0.start < $1.start }.map(\.entry)
        if let last = timeline.indices.last, case .task(let item, _) = timeline[last].item {
            timeline[last].item = .task(item, isLast: true)
        }
        return timeline
    }

    private static func tiles(state: State, wording: TodayWording) -> [TodayScreenDataModel.IdentifiedTile] {
        let colours = TileDataModel.Colour.allCases
        return (state.planned?.tasks ?? [])
            .sorted { $0.rank < $1.rank }
            .enumerated()
            .map { index, task in (task: task, colour: colours[index % colours.count], isNeglected: wording.isNeglected(task)) }
            .sorted { ($0.isNeglected ? 0 : 1, $0.task.rank) < ($1.isNeglected ? 0 : 1, $1.task.rank) }
            .prefix(6)
            .map { task, colour, isNeglected in
                .init(
                    id: task.id,
                    tile: TileDataModel(icon: task.icon, title: task.name, detail: wording.tileDetail(for: task), colour: colour, isNeglected: isNeglected)
                )
            }
    }
}

/// The templated sentences of the Today tab, and the request that asks the on-device model to reword the briefing.
struct TodayWording {
    let state: TodayFeature.State
    let context: PresentationContext

    private var timeStyle: Date.FormatStyle {
        context.timeStyle
    }

    /// The meeting blocks that are not over yet.
    var busyBlocks: [DayContext.Block] {
        (state.planned?.context.blocks ?? []).filter { $0.availability == .busy && $0.interval.end > context.now }
    }

    private var plannedTasks: [TonyTask] {
        var seen: Set<UUID> = []
        return (state.planned?.plan.items ?? []).compactMap { item in
            seen.insert(item.taskID).inserted ? task(of: item) : nil
        }
    }

    var headline: String {
        let locale = context.locale
        let kind =
            switch plannedTasks.count {
            case 0: localized("A free day", locale)
            case 1...2: localized("A light day", locale)
            case 3...4: localized("A steady day", locale)
            default: localized("A full day", locale)
            }
        guard let name = state.userName else { return kind }
        return localized("\(kind), \(name)", locale)
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
        let planItems = state.planned?.plan.items ?? []
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
            otherTaskNames: (state.planned?.tasks ?? []).filter { !plannedIDs.contains($0.id) }.map(\.name)
        )
    }

    /// The first item of the plan when it starts within a quarter of an hour: the moment to do it is now.
    var nowItem: DayPlan.Item? {
        guard let item = state.planned?.plan.items.first, item.interval.start <= context.now.addingTimeInterval(15 * 60) else {
            return nil
        }
        return item
    }

    /// The tasks already done today, in the order they were done.
    var done: String? {
        let calendar = context.calendar
        let tasks = state.planned?.tasks ?? []
        var seen: Set<UUID> = []
        let names = (state.planned?.completions ?? [])
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
        state.planned?.tasks.first { $0.id == item.taskID }
    }

    func title(of step: Step, in task: TonyTask) -> String {
        task.steps.count > 1 ? "\(task.name) · \(step.name)" : task.name
    }

    func isNeglected(_ task: TonyTask) -> Bool {
        task.neglect(completions: state.planned?.completions ?? [], on: context.now, calendar: context.calendar) > 0
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
        let completions = state.planned?.completions ?? []
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
        let lastDone = (state.planned?.completions ?? [])
            .filter { $0.taskID == task.id && $0.stepID == nil && $0.outcome == .done }
            .map(\.date)
            .max()
        return lastDone.flatMap {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: context.now)).day
        }
    }
}
