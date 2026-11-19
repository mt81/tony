import Foundation
import TonyCore
import TonyUIModels

extension TaskEditor {
    /// The sheet for this state. The feature that shows it decides what cancelling, saving and deleting do.
    @MainActor
    static func dataModel(
        for state: State,
        context: PresentationContext,
        edit: @escaping @MainActor (Action) -> Void,
        cancel: any Executable<Void>,
        save: any Executable<Void>,
        delete: any Executable<Void>
    ) -> TaskEditorDataModel {
        let locale = context.locale

        return TaskEditorDataModel(
            id: state.task.id,
            title: state.isNew ? localized("New task", locale) : localized("Edit task", locale),
            composer: state.stage == .reviewing ? nil : composer(state, locale: locale, edit: edit),
            form: state.stage == .reviewing ? form(state, context: context, edit: edit, delete: delete) : nil,
            cancel: ButtonDataModel(title: localized("Cancel", locale), systemImage: "xmark", role: .cancel, action: cancel),
            save: ButtonDataModel(
                title: localized("Save", locale),
                systemImage: "checkmark",
                isEnabled: state.isValid,
                accessibilityIdentifier: "saveTask",
                action: save
            )
        )
    }

    private static func composer(_ state: State, locale: Locale, edit: @escaping @MainActor (Action) -> Void) -> TaskComposerDataModel {
        let isReading = state.stage == .reading
        return TaskComposerDataModel(
            prompt: localized("Describe your task", locale),
            composer: ComposerDataModel(
                text: TextFieldDataModel(
                    title: localized("Describe your task", locale),
                    text: state.sentence,
                    prompt: localized("Water the plants every 5 days", locale),
                    accessibilityIdentifier: "taskSentence",
                    onChange: TonyUIModels.Action(id: "sentenceChanged") { edit(.sentenceChanged($0)) },
                    onSubmit: TonyUIModels.Action(id: "sentenceSent") { _ in edit(.sentenceSent) }
                ),
                send: ButtonDataModel(
                    title: localized("Send", locale),
                    systemImage: "arrow.up",
                    isEnabled: !isReading && !state.trimmedSentence.isEmpty,
                    accessibilityIdentifier: "sendTask",
                    action: TonyUIModels.Action(id: "sentenceSent") { _ in edit(.sentenceSent) }
                ),
                isSending: isReading
            )
        )
    }

    private static func form(
        _ state: State,
        context: PresentationContext,
        edit: @escaping @MainActor (Action) -> Void,
        delete: any Executable<Void>
    ) -> TaskFormDataModel {
        let locale = context.locale
        let task = state.task

        return TaskFormDataModel(
            icon: TextFieldDataModel(
                title: localized("Icon", locale),
                text: task.icon,
                onChange: TonyUIModels.Action(id: "iconChanged") { edit(.iconChanged($0)) }
            ),
            name: TextFieldDataModel(
                title: localized("Name", locale),
                text: task.name,
                accessibilityIdentifier: "taskName",
                onChange: TonyUIModels.Action(id: "nameChanged") { edit(.nameChanged($0)) }
            ),
            scheduleHeader: localized("Schedule", locale),
            repeats: repeats(state, context: context, edit: edit),
            countedFrom: countedFrom(state, locale: locale, edit: edit),
            deadline: deadline(state, locale: locale, edit: edit),
            whenItFitsHeader: localized("When it fits", locale),
            location: location(task.requirements, locale: locale, edit: edit),
            timeOfDay: timeOfDay(task.requirements, locale: locale, edit: edit),
            weather: weather(task.requirements, locale: locale, edit: edit),
            subtasks: subtasks(state, locale: locale, edit: edit),
            delete: state.isNew
                ? nil
                : ButtonDataModel(title: localized("Delete task", locale), role: .destructive, accessibilityIdentifier: "deleteTask", action: delete)
        )
    }

    // MARK: Schedule

    private static func repeats(_ state: State, context: PresentationContext, edit: @escaping @MainActor (Action) -> Void) -> RepeatsDataModel {
        let locale = context.locale
        let choices: [(Repeats, String)] = [
            (.never, localized("Never", locale)),
            (.everyDay, Cadence.Interval(count: 1, unit: .day).text(locale: locale)),
            (.weekdays, localized("Weekdays", locale)),
            (.everyWeek, Cadence.Interval(count: 1, unit: .week).text(locale: locale)),
            (.everyTwoWeeks, Cadence.Interval(count: 2, unit: .week).text(locale: locale)),
            (.everyMonth, Cadence.Interval(count: 1, unit: .month).text(locale: locale)),
            (.everyYear, Cadence.Interval(count: 1, unit: .year).text(locale: locale)),
            (.timesAWeek, localized("Times a week", locale)),
            (.custom, localized("Custom", locale)),
        ]

        return RepeatsDataModel(
            row: DetailRowDataModel(
                systemImage: "repeat",
                title: localized("Repeats", locale),
                value: repeatsValue(state.task.cadence, context: context),
                accessibilityIdentifier: "repeats"
            ),
            choices: PickerDataModel(
                title: localized("Repeats", locale),
                options: choices.map { .init(id: $0.0.rawValue, title: $0.1) },
                selectedID: state.repeats.rawValue,
                onSelect: TonyUIModels.Action(id: "repeatsChanged") { id in Repeats(rawValue: id).map { edit(.repeatsChanged($0)) } }
            ),
            timesPerWeek: state.repeats == .timesAWeek
                ? StepperDataModel(
                    title: localized("\(state.timesPerWeek) times a week", locale),
                    value: state.timesPerWeek,
                    range: 1...7,
                    onChange: TonyUIModels.Action(id: "timesPerWeekChanged") { edit(.timesPerWeekChanged($0)) }
                )
                : nil,
            custom: state.repeats == .custom ? custom(state, context: context, edit: edit) : nil
        )
    }

    /// The custom frequency is the interval's unit, or weekly on fixed weekdays.
    private static func custom(_ state: State, context: PresentationContext, edit: @escaping @MainActor (Action) -> Void) -> CustomRepeatDataModel {
        let locale = context.locale
        let units: [(Cadence.Interval.Unit, String)] = [
            (.day, localized("Daily", locale)),
            (.week, localized("Weekly", locale)),
            (.month, localized("Monthly", locale)),
            (.year, localized("Yearly", locale)),
        ]
        let selectedWeekdays: Set<Locale.Weekday> = if case .weekdays(let days) = state.task.cadence { days } else { [] }
        let unit = state.task.cadence?.interval?.unit ?? .week
        let weekdays =
            unit == .week
            ? context.calendar.orderedWeekdays(locale: locale).map { day in
                ToggleDataModel(
                    id: day.weekday.rawValue,
                    title: day.name.capitalized(with: locale),
                    isOn: selectedWeekdays.contains(day.weekday),
                    onChange: TonyUIModels.Action(id: "weekdayToggled", parameters: day.weekday) { weekday, isOn in edit(.weekdayToggled(weekday, isOn: isOn)) }
                )
            }
            : []

        return CustomRepeatDataModel(
            header: localized("Custom", locale),
            frequency: PickerDataModel(
                title: localized("Frequency", locale),
                options: units.map { .init(id: $0.0.rawValue, title: $0.1) },
                selectedID: unit.rawValue,
                onSelect: TonyUIModels.Action(id: "customUnitChanged") { id in Cadence.Interval.Unit(rawValue: id).map { edit(.customUnitChanged($0)) } }
            ),
            count: state.task.cadence?.interval.map { interval in
                StepperDataModel(
                    title: interval.text(locale: locale),
                    value: interval.count,
                    range: 1...interval.unit.maximumCount,
                    onChange: TonyUIModels.Action(id: "intervalCountChanged") { edit(.intervalCountChanged($0)) }
                )
            },
            weekdays: weekdays
        )
    }

    private static func repeatsValue(_ cadence: Cadence?, context: PresentationContext) -> String {
        let locale = context.locale
        switch cadence {
        case nil:
            return localized("Never", locale)
        case .interval(let interval, _):
            return interval.text(locale: locale)
        case .weekdays(let weekdays) where weekdays == TaskEditor.workweek:
            return localized("Weekdays", locale)
        case .weekdays(let weekdays):
            let names = context.calendar.orderedWeekdays(locale: locale).filter { weekdays.contains($0.weekday) }.map(\.name)
            return localized("Every \(names.formatted(.list(type: .and).locale(locale)))", locale)
        case .timesPerWeek(let times):
            return localized("\(times) times a week", locale)
        }
    }

    private static func countedFrom(_ state: State, locale: Locale, edit: @escaping @MainActor (Action) -> Void) -> CountedFromDataModel? {
        guard case .interval(_, let anchor) = state.task.cadence else { return nil }
        let lastTime = localized("Last time done", locale)
        let fixed = localized("Fixed schedule", locale)
        let start: Date? = if case .schedule(let start) = anchor { start } else { nil }

        return CountedFromDataModel(
            row: DetailRowDataModel(
                systemImage: "checkmark.circle",
                title: localized("Counted from", locale),
                value: start == nil ? lastTime : fixed,
                accessibilityIdentifier: "countedFrom"
            ),
            choices: PickerDataModel(
                title: localized("Counted from", locale),
                options: [.init(id: "lastTime", title: lastTime), .init(id: "fixed", title: fixed)],
                selectedID: start == nil ? "lastTime" : "fixed",
                onSelect: TonyUIModels.Action(id: "countedFromChanged") { id in edit(.countedFromChanged(isFixed: id == "fixed")) }
            ),
            start: start.map { start in
                DatePickerDataModel(
                    title: localized("Starts", locale),
                    date: start,
                    onChange: TonyUIModels.Action(id: "scheduleStartChanged") { edit(.scheduleStartChanged($0)) }
                )
            }
        )
    }

    private static func deadline(_ state: State, locale: Locale, edit: @escaping @MainActor (Action) -> Void) -> DeadlineDataModel {
        DeadlineDataModel(
            row: DetailRowDataModel(
                systemImage: "calendar",
                title: localized("Deadline", locale),
                value: state.hasDeadline
                    ? state.deadline.formatted(.dateTime.day().month(.abbreviated).locale(locale))
                    : localized("None", locale),
                accessibilityIdentifier: "deadline"
            ),
            toggle: ToggleDataModel(
                id: "deadline",
                title: localized("Must happen by a date", locale),
                isOn: state.hasDeadline,
                onChange: TonyUIModels.Action(id: "deadlineToggled") { edit(.deadlineToggled($0)) }
            ),
            date: state.hasDeadline
                ? DatePickerDataModel(title: localized("Date", locale), date: state.deadline, onChange: TonyUIModels.Action(id: "deadlineChanged") { edit(.deadlineChanged($0)) })
                : nil
        )
    }

    // MARK: When it fits

    private static func location(_ requirements: Requirements, locale: Locale, edit: @escaping @MainActor (Action) -> Void) -> ChoiceDataModel {
        let anywhere = "anywhere"
        let options: [PickerDataModel.Option] = [
            .init(id: anywhere, title: localized("Anywhere", locale)),
            .init(id: Location.home.rawValue, title: localized("At home", locale)),
            .init(id: Location.office.rawValue, title: localized("At the office", locale)),
        ]
        let selectedID = requirements.location.map(\.rawValue).flatMap { id in options.contains { $0.id == id } ? id : nil } ?? anywhere

        return ChoiceDataModel(
            row: DetailRowDataModel(
                systemImage: "location",
                title: localized("Where", locale),
                value: options.first { $0.id == selectedID }?.title ?? "",
                accessibilityIdentifier: "where"
            ),
            choices: PickerDataModel(
                title: localized("Where", locale),
                options: options,
                selectedID: selectedID,
                onSelect: TonyUIModels.Action(id: "locationChanged") { id in edit(.locationChanged(Location(rawValue: id))) }
            )
        )
    }

    private static func timeOfDay(_ requirements: Requirements, locale: Locale, edit: @escaping @MainActor (Action) -> Void) -> ChecklistDataModel {
        let windows: [(Window, String)] = [
            (.morning, localized("Morning", locale)),
            (.workday, localized("Work hours", locale)),
            (.evening, localized("Evening", locale)),
        ]
        let anyTime = localized("Any time", locale)
        let chosen = windows.filter { requirements.windows.contains($0.0) }.map(\.1)

        return ChecklistDataModel(
            row: DetailRowDataModel(
                systemImage: "clock",
                title: localized("Time of day", locale),
                value: chosen.isEmpty ? anyTime : chosen.formatted(.list(type: .and).locale(locale)),
                accessibilityIdentifier: "timeOfDay"
            ),
            items: [
                ToggleDataModel(
                    id: "any",
                    title: anyTime,
                    isOn: chosen.isEmpty,
                    onChange: TonyUIModels.Action(id: "windowToggled", parameters: Window?.none) { window, isOn in edit(.windowToggled(window, isOn: isOn)) }
                )
            ] + windows.map { window, title in
                ToggleDataModel(
                    id: window.rawValue,
                    title: title,
                    isOn: requirements.windows.contains(window),
                    onChange: TonyUIModels.Action(id: "windowToggled", parameters: Optional(window)) { window, isOn in edit(.windowToggled(window, isOn: isOn)) }
                )
            }
        )
    }

    private static func weather(_ requirements: Requirements, locale: Locale, edit: @escaping @MainActor (Action) -> Void) -> ChecklistDataModel {
        let avoided = requirements.avoidedWeather
        let value =
            switch (avoided.contains(.rain), avoided.contains(.snow)) {
            case (true, true): localized("Not in rain or snow", locale)
            case (true, false): localized("Not in the rain", locale)
            case (false, true): localized("Not in the snow", locale)
            case (false, false): localized("Any weather", locale)
            }
        let conditions: [(WeatherCondition, String)] = [
            (.rain, localized("Not in the rain", locale)),
            (.snow, localized("Not in the snow", locale)),
        ]

        return ChecklistDataModel(
            row: DetailRowDataModel(systemImage: "cloud.rain", title: localized("Weather", locale), value: value, accessibilityIdentifier: "weather"),
            items: [
                ToggleDataModel(
                    id: "any",
                    title: localized("Any weather", locale),
                    isOn: avoided.isEmpty,
                    onChange: TonyUIModels.Action(id: "weatherToggled", parameters: WeatherCondition?.none) { condition, isOn in edit(.weatherToggled(condition, isOn: isOn)) }
                )
            ] + conditions.map { condition, title in
                ToggleDataModel(
                    id: condition.rawValue,
                    title: title,
                    isOn: avoided.contains(condition),
                    onChange: TonyUIModels.Action(id: "weatherToggled", parameters: Optional(condition)) { condition, isOn in edit(.weatherToggled(condition, isOn: isOn)) }
                )
            }
        )
    }

    // MARK: Sub tasks

    static let durationChoices = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 360, 480]

    private static func subtasks(_ state: State, locale: Locale, edit: @escaping @MainActor (Action) -> Void) -> SubtasksSectionDataModel {
        let steps = state.task.steps
        let namePrompt = state.trimmedName.isEmpty ? localized("Sub task", locale) : state.trimmedName

        return SubtasksSectionDataModel(
            header: localized("Sub tasks", locale),
            subtasks: steps.map { step in
                let minutes = Int(step.duration / 60)
                let choices = Set(durationChoices + [minutes]).sorted()
                return SubtaskDataModel(
                    id: step.id,
                    name: TextFieldDataModel(
                        title: localized("Sub task", locale),
                        text: step.name,
                        prompt: namePrompt,
                        onChange: TonyUIModels.Action(id: "stepNameChanged", parameters: step.id) { id, name in edit(.stepNameChanged(id: id, name: name)) }
                    ),
                    duration: PickerDataModel(
                        title: localized("Duration", locale),
                        options: choices.map { .init(id: String($0), title: durationText(minutes: $0, locale: locale)) },
                        selectedID: String(minutes),
                        onSelect: TonyUIModels.Action(id: "stepMinutesChanged", parameters: step.id) { id, minutes in
                            Int(minutes).map { edit(.stepMinutesChanged(id: id, minutes: $0)) }
                        }
                    )
                )
            },
            add: ButtonDataModel(
                title: localized("Add a sub task", locale),
                systemImage: "plus",
                accessibilityIdentifier: "addSubtask",
                action: TonyUIModels.Action(id: "stepAdded") { _ in edit(.stepAdded(id: UUID())) }
            ),
            canDelete: steps.count > 1,
            move: TonyUIModels.Action(id: "stepsMoved") { move in edit(.stepsMoved(from: move.source, to: move.destination)) },
            delete: TonyUIModels.Action(id: "stepsDeleted") { edit(.stepsDeleted($0)) }
        )
    }

    /// "45 min", "1 hr 30 min".
    static func durationText(minutes: Int, locale: Locale) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
    }
}

extension TaskEditor {
    /// Asks the catalogue for the steps of a task with this name, once typing has paused. Nil when typing went on.
    static func suggestSteps(
        forName name: String,
        catalog: (any TaskCatalog)?,
        locale: Locale,
        after delay: Duration
    ) async -> Action? {
        do {
            try await Task.sleep(for: delay)
        } catch {
            return nil
        }
        guard !name.isEmpty, let catalog else {
            return .stepsSuggested(forName: name, steps: nil)
        }
        let templates = try? await catalog.steps(forTaskNamed: name, locale: locale)
        return .stepsSuggested(forName: name, steps: templates?.map { $0.step(id: UUID()) })
    }
}
