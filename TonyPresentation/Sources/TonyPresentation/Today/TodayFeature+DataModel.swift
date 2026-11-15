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
        let wording = Wording(state: state, context: context)

        return TodayScreenDataModel(
            date: context.now.formatted(wording.dayStyle),
            headline: wording.headline,
            consistency: state.mocked.map { consistency(week: $0.week, context: context) },
            briefing: BriefingDataModel(
                author: localized("Tony", locale),
                time: state.planned.map { "· \($0.plannedAt.formatted(wording.timeStyle))" } ?? "",
                text: wording.briefing,
                question: state.mocked?.question.map { question in
                    switch question {
                    case .lunchPlanned: localized("Do you already have something planned for lunch?", locale)
                    }
                },
                answers: state.mocked?.question == nil
                    ? []
                    : [localized("Yes, sorted", locale), localized("Not yet", locale), localized("Skip it", locale)].map { title in
                        ButtonDataModel(title: title) { send(.questionAnswered) }
                    }
            ),
            timelineTitle: localized("Your day", locale),
            timelineHint: localized("Suggestions, not orders", locale),
            timeline: timeline(state: state, wording: wording, send: send),
            tilesTitle: localized("How things are", locale),
            tiles: tiles(state: state, wording: wording),
            alert: state.hasFailed
                ? AlertDataModel(
                    title: localized("Your answer could not be saved", locale),
                    dismiss: ButtonDataModel(title: localized("OK", locale)) { send(.alertDismissed) }
                )
                : nil,
            onAppear: { send(.appeared) }
        )
    }

    @MainActor
    private static func timeline(
        state: State,
        wording: Wording,
        send: @escaping @MainActor (Action) -> Void
    ) -> [TodayScreenDataModel.TimelineEntry] {
        let locale = wording.context.locale
        let items = state.planned?.plan.items ?? []
        let firstItemID = items.first?.id

        var entries: [(start: Date, entry: TodayScreenDataModel.TimelineEntry)] = []
        for item in items {
            guard let task = wording.task(of: item), let step = task.steps.first(where: { $0.id == item.stepID }) else { continue }
            let title = wording.title(of: step, in: task)
            var actions: [ButtonDataModel] = []
            if item.id == firstItemID {
                actions.append(ButtonDataModel(title: localized("Later", locale), accessibilityIdentifier: "today-later") { send(.laterTapped(item)) })
                if task.mustHappenBy == nil {
                    actions.append(
                        ButtonDataModel(title: localized("Not today", locale), accessibilityIdentifier: "today-notToday") { send(.notTodayTapped(item)) }
                    )
                }
            }
            let taskItem = TimelineItemDataModel.TaskItem(
                icon: task.icon,
                time: item.interval.start.formatted(wording.timeStyle),
                title: title,
                reason: wording.reason(for: item, step: step, task: task),
                actions: actions,
                check: ButtonDataModel(title: localized("Mark \(title) as done", locale), accessibilityIdentifier: "today-check-\(title)") {
                    send(.checkTapped(item))
                },
                isNeglected: wording.isNeglected(task),
                accessibilityIdentifier: "today-item-\(title)"
            )
            entries.append((item.interval.start, .init(id: item.stepID.uuidString, item: .task(taskItem, isLast: false))))
        }
        for block in wording.busyBlocks {
            let start = block.interval.start
            let item = TimelineItemDataModel.meetings(
                time: start.formatted(wording.timeStyle),
                title: localized("\(block.eventCount) meetings, back to back", locale),
                detail: wording.meetingsDetail(for: block)
            )
            entries.append((start, .init(id: "meetings-\(start.timeIntervalSinceReferenceDate)", item: item)))
        }

        var timeline = [TodayScreenDataModel.TimelineEntry(id: "now", item: .now(text: wording.now))]
        timeline += entries.sorted { $0.start < $1.start }.map(\.entry)
        if let last = timeline.indices.last, case .task(let item, _) = timeline[last].item {
            timeline[last].item = .task(item, isLast: true)
        }
        return timeline
    }

    private static func tiles(state: State, wording: Wording) -> [TodayScreenDataModel.IdentifiedTile] {
        (state.planned?.tasks ?? [])
            .map { (task: $0, isNeglected: wording.isNeglected($0)) }
            .sorted { ($0.isNeglected ? 0 : 1, $0.task.rank) < ($1.isNeglected ? 0 : 1, $1.task.rank) }
            .prefix(6)
            .map { task, isNeglected in
                .init(
                    id: task.id,
                    tile: TileDataModel(icon: task.icon, title: task.name, detail: wording.tileDetail(for: task), isNeglected: isNeglected)
                )
            }
    }

    private static func consistency(week: [Mocked.DayScore], context: PresentationContext) -> ConsistencyDataModel {
        let (calendar, locale) = (context.calendar, context.locale)
        var localised = calendar
        localised.locale = locale
        let todayOffset = (calendar.component(.weekday, from: context.now) - calendar.firstWeekday + 7) % 7

        var level = 0.5
        var spoken: [String] = []
        let days = (0..<7).map { offset -> ConsistencyDataModel.Day in
            let symbol = (calendar.firstWeekday - 1 + offset) % 7
            let letter = localised.veryShortStandaloneWeekdaySymbols[symbol]
            guard offset <= todayOffset, week.indices.contains(offset) else {
                return .init(id: offset, letter: letter, value: "·", level: level, kind: .upcoming, isToday: false)
            }
            let value: String
            let kind: ConsistencyDataModel.Day.Kind
            switch week[offset] {
            case .score(let done, let suggested):
                value = "\(done.formatted(.number.locale(locale)))/\(suggested.formatted(.number.locale(locale)))"
                level = suggested > 0 ? Double(done) / Double(suggested) : level
                kind = .scored
            case .rest:
                value = localized("rest", locale)
                kind = .rest
            }
            spoken.append("\(localised.standaloneWeekdaySymbols[symbol]) \(value)")
            return .init(id: offset, letter: letter, value: value, level: level, kind: kind, isToday: offset == todayOffset)
        }

        let title = localized("Your consistency", locale)
        return ConsistencyDataModel(
            title: title,
            caption: localized("done / suggested", locale),
            days: days,
            footnote: localized("Higher means you followed through on more of what Tony suggested. Rest days stay on the path.", locale),
            accessibilityLabel: ([title] + spoken).formatted(.list(type: .and, width: .narrow).locale(locale))
        )
    }
}

/// The templated sentences of the Today tab. The on-device model will reword the briefing later (C15).
private struct Wording {
    let state: TodayFeature.State
    let context: PresentationContext

    var timeStyle: Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened).locale(context.locale)
        style.timeZone = context.calendar.timeZone
        return style
    }

    var dayStyle: Date.FormatStyle {
        var style = Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day().locale(context.locale)
        style.timeZone = context.calendar.timeZone
        return style
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
        guard let name = state.mocked?.userName else { return kind }
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

    var now: String {
        let locale = context.locale
        guard
            let item = state.planned?.plan.items.first,
            item.interval.start <= context.now.addingTimeInterval(15 * 60),
            let task = task(of: item),
            let step = task.steps.first(where: { $0.id == item.stepID })
        else {
            return localized("Now", locale)
        }
        return localized("Now · a good moment for \(title(of: step, in: task))", locale)
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
        let locale = context.locale
        let titles = Array((state.mocked?.meetingTitles ?? []).prefix(min(2, block.eventCount)))
        let more = block.eventCount - titles.count
        var parts = titles
        if !titles.isEmpty && more > 0 {
            parts.append(localized("\(more) more", locale))
        }
        parts.append(localized("until \(block.interval.end.formatted(timeStyle))", locale))
        return parts.joined(separator: " · ")
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
