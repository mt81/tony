import Foundation
import MemberwiseInit
import TonyCore
import TonyUIModels

/// What the Today tab shows, read from its store: Tony, the briefing, the day as a timeline, and the tiles.
/// Each value comes from a reducer that takes the whole state, so a view redraws only when what it reads changes.
@MainActor
public struct TodayViewModel {
    @MemberwiseInit(.public)
    public struct TimelineEntry: Identifiable, Equatable {
        public var id: String
        public var item: TimelineItemDataModel
    }

    @MemberwiseInit(.public)
    public struct IdentifiedTile: Identifiable, Hashable, Sendable {
        public var id: UUID
        public var tile: TileDataModel
    }

    private let store: TodayStore
    private let context: PresentationContext

    public init(store: TodayStore, context: PresentationContext) {
        self.store = store
        self.context = context
    }

    public var date: String { Self.date(store.state, context: context) }
    /// The kind of day, its word emphasised: "A *light* day, Matteo".
    public var headline: AttributedString { Self.headline(store.state, context: context) }
    /// What Tony says about the day.
    public var briefing: String { Self.briefing(store.state, context: context) }
    /// Asks for the calendar while Tony cannot read it; nil once he can.
    public var calendar: CalendarCardDataModel? { Self.calendar(store.state, context: context, store: store) }
    public var timelineTitle: String { localized("Your day", context.locale) }
    public var timeline: [TimelineEntry] { Self.timeline(store.state, context: context, store: store) }
    public var tilesTitle: String { localized("How things are", context.locale) }
    public var tiles: [IdentifiedTile] { Self.tiles(store.state, context: context) }
    /// The task form, while a task is being added.
    public var editor: TaskEditorDataModel? { Self.editor(store.state, context: context, store: store) }
    public var alert: AlertDataModel? { Self.alert(store.state, context: context, store: store) }

    public var dismissEditor: any Executable<Void> {
        Action(id: "cancel_editing") { [store] _ in store.cancelEditing() }
    }

    public func load() async {
        await store.load()
    }

    // MARK: Reducers

    static func date(_ state: TodayState, context: PresentationContext) -> String {
        context.now.formatted(context.dayStyle)
    }

    static func headline(_ state: TodayState, context: PresentationContext) -> AttributedString {
        wording(state, context: context).headline
    }

    static func briefing(_ state: TodayState, context: PresentationContext) -> String {
        state.briefing.flatMap { $0.plan == state.planned?.plan ? $0.text : nil } ?? wording(state, context: context).briefing
    }

    static func calendar(_ state: TodayState, context: PresentationContext, store: TodayStore) -> CalendarCardDataModel? {
        guard let access = state.calendarAccess, access != .granted else { return nil }
        let locale = context.locale
        return CalendarCardDataModel(
            title: localized("Calendar", locale),
            text: localized("Tony doesn’t see your calendar yet, so he can’t plan around your meetings.", locale),
            allow: ButtonDataModel(
                title: localized("Plan around my events", locale),
                accessibilityIdentifier: "planAroundEvents",
                action: Action(id: "plan_around_events") { _ in Task { await store.planAroundEvents() } }
            )
        )
    }

    static func timeline(_ state: TodayState, context: PresentationContext, store: TodayStore) -> [TimelineEntry] {
        let locale = context.locale
        let wording = wording(state, context: context)
        let items = state.planned?.plan.items ?? []
        let firstItemID = items.first?.id
        let nowItemID = wording.nowItem?.id

        var entries: [(start: Date, entry: TimelineEntry)] = []
        for item in items {
            guard let task = wording.task(of: item), let step = task.steps.first(where: { $0.id == item.stepID }) else { continue }
            let title = wording.title(of: step, in: task)
            var actions: [ButtonDataModel] = []
            if item.id == firstItemID {
                actions.append(
                    ButtonDataModel(
                        title: localized("Later", locale),
                        accessibilityIdentifier: "today-later",
                        action: Action(id: "postpone", parameters: item) { item, _ in Task { await store.postpone(item) } }
                    )
                )
                if task.mustHappenBy == nil {
                    actions.append(
                        ButtonDataModel(
                            title: localized("Not today", locale),
                            accessibilityIdentifier: "today-notToday",
                            action: Action(id: "refuse", parameters: item) { item, _ in Task { await store.refuse(item) } }
                        )
                    )
                }
            }
            let time = item.interval.start.formatted(context.timeStyle)
            let taskItem = TimelineItemDataModel.TaskItem(
                icon: task.icon,
                time: time,
                title: title,
                reason: wording.reason(for: item, step: step, task: task),
                actions: actions,
                check: ButtonDataModel(
                    title: localized("Mark \(title) as done", locale),
                    accessibilityIdentifier: "today-check-\(title)",
                    action: Action(id: "check", parameters: item) { item, _ in Task { await store.check(item) } }
                ),
                isNeglected: wording.isNeglected(task),
                now: item.id == nowItemID ? localized("\(time) · a good moment to start", locale) : nil,
                accessibilityIdentifier: "today-item-\(title)"
            )
            entries.append((item.interval.start, TimelineEntry(id: item.stepID.uuidString, item: .task(taskItem, isLast: false))))
        }
        for block in wording.busyBlocks {
            let start = block.interval.start
            let item = TimelineItemDataModel.meetings(
                time: start.formatted(context.timeStyle),
                title: localized("\(block.eventCount) meetings, back to back", locale),
                detail: wording.meetingsDetail(for: block)
            )
            entries.append((start, TimelineEntry(id: "meetings-\(start.timeIntervalSinceReferenceDate)", item: item)))
        }

        var timeline: [TimelineEntry] = []
        if let done = wording.done {
            timeline.append(TimelineEntry(id: "done", item: .done(text: done)))
        }
        if nowItemID == nil {
            timeline.append(TimelineEntry(id: "now", item: .now(text: localized("Now", locale))))
        }
        timeline += entries.sorted { $0.start < $1.start }.map(\.entry)
        if let last = timeline.indices.last, case .task(let item, _) = timeline[last].item {
            timeline[last].item = .task(item, isLast: true)
        }
        return timeline
    }

    static func tiles(_ state: TodayState, context: PresentationContext) -> [IdentifiedTile] {
        let wording = wording(state, context: context)
        let colours = TileDataModel.Colour.allCases
        return (state.planned?.tasks ?? [])
            .sorted { $0.rank < $1.rank }
            .enumerated()
            .map { index, task in (task: task, colour: colours[index % colours.count], isNeglected: wording.isNeglected(task)) }
            .sorted { ($0.isNeglected ? 0 : 1, $0.task.rank) < ($1.isNeglected ? 0 : 1, $1.task.rank) }
            .prefix(6)
            .map { task, colour, isNeglected in
                IdentifiedTile(
                    id: task.id,
                    tile: TileDataModel(icon: task.icon, title: task.name, detail: wording.tileDetail(for: task), colour: colour, isNeglected: isNeglected)
                )
            }
    }

    static func editor(_ state: TodayState, context: PresentationContext, store: TodayStore) -> TaskEditorDataModel? {
        state.editor.map { editor in
            TaskEditor.dataModel(
                for: editor,
                context: context,
                edit: { store.edit($0) },
                cancel: Action(id: "cancel_editing") { _ in store.cancelEditing() },
                save: Action(id: "save_task") { _ in Task { await store.saveEditor() } },
                delete: Action(id: "nothing") { _ in }
            )
        }
    }

    static func alert(_ state: TodayState, context: PresentationContext, store: TodayStore) -> AlertDataModel? {
        guard let failure = state.failure else { return nil }
        let locale = context.locale
        let title =
            switch failure {
            case .answer: localized("Your answer could not be saved", locale)
            case .task: localized("Your tasks could not be saved", locale)
            }
        return AlertDataModel(
            title: title,
            dismiss: ButtonDataModel(
                title: localized("OK", locale),
                action: Action(id: "dismiss_alert") { _ in store.dismissAlert() }
            )
        )
    }

    private static func wording(_ state: TodayState, context: PresentationContext) -> TodayWording {
        TodayWording(planned: state.planned, userName: state.userName, context: context)
    }
}
