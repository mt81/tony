import Foundation
import TonyCore
import TonyUIModels

/// What the You tab shows, read from its store. Each value comes from a reducer that takes the whole state,
/// and a view redraws only when the parts of the state its reducers read change.
@MainActor
public struct YouViewModel {
    private let store: YouStore
    private let context: PresentationContext

    public init(store: YouStore, context: PresentationContext) {
        self.store = store
        self.context = context
    }

    /// The first letter of the name; nil when there is no name.
    public var initial: String? { Self.initial(store.state, context: context) }
    public var name: String { Self.name(store.state, context: context) }
    public var routine: RoutineCardDataModel { Self.routine(store.state, context: context, store: store) }
    public var calendar: CalendarCardDataModel { Self.calendar(store.state, context: context, store: store) }
    public var isEditing: Bool { Self.isEditing(store.state) }
    public var editor: RoutineEditorDataModel? { Self.editor(store.state, context: context, store: store) }
    public var alert: AlertDataModel? { Self.alert(store.state, context: context, store: store) }

    public func load() async {
        await store.load()
    }

    public func dismissEditor() {
        store.cancelEditing()
    }

    // MARK: Reducers

    static func initial(_ state: YouState, context: PresentationContext) -> String? {
        state.name.first.map { String($0).uppercased(with: context.locale) }
    }

    static func name(_ state: YouState, context: PresentationContext) -> String {
        state.name.isEmpty ? localized("You", context.locale) : state.name
    }

    static func routine(_ state: YouState, context: PresentationContext, store: YouStore) -> RoutineCardDataModel {
        let locale = context.locale
        let routine = state.routine
        let weekdays = context.calendar.orderedWeekdays(locale: locale)
        func names(_ days: Set<Locale.Weekday>) -> String {
            weekdays.filter { days.contains($0.weekday) }.map(\.shortName).formatted(.list(type: .and, width: .narrow).locale(locale))
        }
        func time(_ components: DateComponents) -> String {
            date(components, context: context).formatted(context.timeStyle)
        }

        var places: [String] = []
        if !routine.homeDays.isEmpty {
            places.append(localized("Home on \(names(routine.homeDays))", locale))
        }
        if !routine.officeDays.isEmpty {
            places.append(localized("Office on \(names(routine.officeDays))", locale))
        }
        return RoutineCardDataModel(
            title: localized("Your routine", locale),
            edit: ButtonDataModel(
                title: localized("Edit", locale),
                accessibilityIdentifier: "editRoutine",
                action: Action("edit_routine") { _ in store.startEditing() }
            ),
            lines: [
                places.isEmpty ? localized("No working days", locale) : places.joined(separator: " · "),
                localized("Workday \(time(routine.workStart)) to \(time(routine.workEnd))", locale),
                localized("Up around \(time(routine.wakeTime)) · bed around \(time(routine.bedtime))", locale),
            ]
        )
    }

    static func calendar(_ state: YouState, context: PresentationContext, store: YouStore) -> CalendarCardDataModel {
        let locale = context.locale
        let text =
            switch state.calendarAccess {
            case .granted: localized("Tony plans around your meetings. He reads when you are busy, never what the events are about.", locale)
            case .denied: localized("Calendar access is off. Turn it on in Settings so Tony can plan around your meetings.", locale)
            case .notDetermined, nil:
                localized("Let Tony plan around your meetings. He reads when you are busy, never what the events are about.", locale)
            }
        return CalendarCardDataModel(
            title: localized("Calendar", locale),
            text: text,
            allow: state.calendarAccess == .notDetermined
                ? ButtonDataModel(
                    title: localized("Allow calendar access", locale),
                    accessibilityIdentifier: "allowCalendar",
                    action: Action("allow_calendar") { _ in Task { await store.allowCalendar() } }
                )
                : nil
        )
    }

    static func isEditing(_ state: YouState) -> Bool {
        state.editor != nil
    }

    static func editor(_ state: YouState, context: PresentationContext, store: YouStore) -> RoutineEditorDataModel? {
        guard let editor = state.editor else { return nil }
        let locale = context.locale
        let kinds: [PickerDataModel.Option] = [
            .init(id: YouState.DayKind.home.rawValue, title: localized("At home", locale)),
            .init(id: YouState.DayKind.office.rawValue, title: localized("At the office", locale)),
            .init(id: YouState.DayKind.off.rawValue, title: localized("Day off", locale)),
        ]
        func timePicker(_ title: String, _ field: YouState.TimeField, _ components: DateComponents) -> TimePickerDataModel {
            TimePickerDataModel(title: title, time: date(components, context: context)) { newTime in
                store.changeTime(field, to: context.calendar.dateComponents([.hour, .minute], from: newTime))
            }
        }

        return RoutineEditorDataModel(
            title: localized("Your routine", locale),
            name: TextFieldDataModel(
                title: localized("Your name", locale),
                text: editor.name,
                accessibilityIdentifier: "userName",
                onChange: { store.changeName($0) }
            ),
            description: TextFieldDataModel(
                title: localized("Describe your week", locale),
                text: editor.description,
                prompt: localized("Tell Tony… “office on Tuesdays and Thursdays, 9 to 5:30”", locale),
                accessibilityIdentifier: "routineDescription",
                onChange: { store.changeDescription($0) },
                onSubmit: { Task { await store.readDescription() } }
            ),
            descriptionFooter: {
                switch editor.reading {
                case .none: nil
                case .inProgress: localized("Tony is reading…", locale)
                case .filled: localized("Tony filled in the form below. Check it before you save.", locale)
                case .notUnderstood: localized("Tony could not read that. Fill in the form below.", locale)
                }
            }(),
            daysHeader: localized("Your week", locale),
            days: context.calendar.orderedWeekdays(locale: locale).map { day in
                .init(
                    id: day.weekday.rawValue,
                    picker: PickerDataModel(
                        title: day.name.capitalized(with: locale),
                        options: kinds,
                        selectedID: editor.kind(of: day.weekday).rawValue,
                        onSelect: { id in YouState.DayKind(rawValue: id).map { store.changeDay(day.weekday, to: $0) } }
                    )
                )
            },
            workHeader: localized("Work hours", locale),
            workStart: timePicker(localized("Starts", locale), .workStart, editor.routine.workStart),
            workEnd: timePicker(localized("Ends", locale), .workEnd, editor.routine.workEnd),
            workFooter: editor.isValid ? nil : localized("Work has to end after it starts.", locale),
            sleepHeader: localized("Sleep", locale),
            wakeTime: timePicker(localized("Up around", locale), .wakeTime, editor.routine.wakeTime),
            bedtime: timePicker(localized("Bed around", locale), .bedtime, editor.routine.bedtime),
            cancel: ButtonDataModel(
                title: localized("Cancel", locale),
                systemImage: "xmark",
                role: .cancel,
                action: Action("cancel_editing") { _ in store.cancelEditing() }
            ),
            save: ButtonDataModel(
                title: localized("Save", locale),
                systemImage: "checkmark",
                isEnabled: editor.isValid,
                accessibilityIdentifier: "saveRoutine",
                action: Action("save_routine") { _ in Task { await store.save() } }
            )
        )
    }

    static func alert(_ state: YouState, context: PresentationContext, store: YouStore) -> AlertDataModel? {
        guard state.hasFailed else { return nil }
        return AlertDataModel(
            title: localized("Your routine could not be saved", context.locale),
            dismiss: ButtonDataModel(
                title: localized("OK", context.locale),
                role: .cancel,
                action: Action("dismiss_alert") { _ in store.dismissAlert() }
            )
        )
    }

    /// The time of day on the day being shown, for formatting and for the time pickers.
    private static func date(_ time: DateComponents, context: PresentationContext) -> Date {
        context.calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: context.now) ?? context.now
    }
}
