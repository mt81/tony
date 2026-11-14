import Foundation
import TonyCore
import TonyUIKit

extension TasksFeature {
    @MainActor
    public static func dataModel(
        for state: State,
        context: PresentationContext,
        send: @escaping @MainActor (Action) -> Void
    ) -> TasksScreenDataModel {
        let locale = context.locale
        let addTask: @MainActor () -> Void = { send(.addTapped(id: UUID(), stepID: UUID(), now: Date())) }

        return TasksScreenDataModel(
            title: localized("Tasks", locale),
            add: ButtonDataModel(title: localized("Add a task", locale), systemImage: "plus", accessibilityIdentifier: "addTask", action: addTask),
            sections: kinds.compactMap { kind in
                section(kind, state: state, context: context, send: send)
            },
            addTask: ButtonDataModel(title: localized("+ Add a task", locale), action: addTask),
            editor: state.editor.map { editor in
                editorDataModel(editor, context: context, send: send)
            },
            dismissEditor: { send(.editorCancelled) },
            alert: state.hasFailed
                ? AlertDataModel(
                    title: localized("Your tasks could not be saved", locale),
                    dismiss: ButtonDataModel(title: localized("OK", locale), role: .cancel) { send(.alertDismissed) }
                )
                : nil,
            onAppear: { send(.appeared) }
        )
    }

    private static func section(
        _ kind: TonyTask.Kind,
        state: State,
        context: PresentationContext,
        send: @escaping @MainActor (Action) -> Void
    ) -> TaskSectionDataModel? {
        let tasks = state.tasks.filter { $0.kind == kind }
        guard !tasks.isEmpty else { return nil }
        let locale = context.locale
        let (title, hint): (String, String?) =
            switch kind {
            case .recurring: (localized("Recurring", locale), localized("Top matters most", locale))
            case .goal: (localized("Goals", locale), localized("Flexible days", locale))
            case .oneTime: (localized("One-time", locale), nil)
            }

        return TaskSectionDataModel(
            id: kind.rawValue,
            title: title,
            hint: hint,
            rows: tasks.map { task in
                let summary = TaskSummary(task: task, completions: state.completions, context: context)
                return TaskRowDataModel(
                    id: task.id,
                    icon: task.icon,
                    title: task.name,
                    subtitle: summary.subtitle,
                    status: ChipDataModel(title: summary.status, style: summary.isNeglected ? .warning : .neutral),
                    isNeglected: summary.isNeglected,
                    accessibilityIdentifier: "task-\(task.name)",
                    open: { send(.rowTapped(id: task.id, now: Date())) },
                    delete: ButtonDataModel(title: localized("Delete", locale), role: .destructive) { send(.deleteTapped(id: task.id)) }
                )
            },
            move: { source, destination in send(.moved(kind: kind, from: source, to: destination)) }
        )
    }

    // MARK: Editor

    private static func editorDataModel(
        _ state: TaskEditor.State,
        context: PresentationContext,
        send: @escaping @MainActor (Action) -> Void
    ) -> TaskEditorDataModel {
        let locale = context.locale
        let edit: @MainActor (TaskEditor.Action) -> Void = { send(.editor($0)) }
        let task = state.task

        return TaskEditorDataModel(
            id: task.id,
            title: state.isNew ? localized("New task", locale) : localized("Edit task", locale),
            name: TextFieldDataModel(
                title: localized("Name", locale),
                text: task.name,
                accessibilityIdentifier: "taskName",
                onChange: { edit(.nameChanged($0)) }
            ),
            icon: TextFieldDataModel(title: localized("Icon", locale), text: task.icon, onChange: { edit(.iconChanged($0)) }),
            kind: PickerDataModel(
                title: localized("Kind", locale),
                options: [
                    .init(id: TonyTask.Kind.recurring.rawValue, title: localized("Recurring task", locale)),
                    .init(id: TonyTask.Kind.goal.rawValue, title: localized("Goal", locale)),
                    .init(id: TonyTask.Kind.oneTime.rawValue, title: localized("One-time task", locale)),
                ],
                selectedID: task.kind.rawValue,
                onSelect: { id in TonyTask.Kind(rawValue: id).map { edit(.kindChanged($0)) } }
            ),
            cadence: task.kind == .oneTime ? nil : cadenceSection(state, context: context, edit: edit),
            whenItFits: whenItFitsSection(state, locale: locale, edit: edit),
            steps: stepsSection(state, locale: locale, edit: edit),
            deadline: DeadlineSectionDataModel(
                header: localized("Deadline", locale),
                toggle: ToggleDataModel(
                    id: "deadline",
                    title: localized("Must happen by a date", locale),
                    isOn: state.hasDeadline,
                    onChange: { edit(.deadlineToggled($0)) }
                ),
                date: state.hasDeadline
                    ? DatePickerDataModel(title: localized("Date", locale), date: state.deadline, onChange: { edit(.deadlineChanged($0)) })
                    : nil
            ),
            delete: state.isNew
                ? nil
                : ButtonDataModel(
                    title: localized("Delete task", locale),
                    role: .destructive,
                    accessibilityIdentifier: "deleteTask",
                    action: { send(.editorDeleted) }
                ),
            cancel: ButtonDataModel(title: localized("Cancel", locale), systemImage: "xmark", role: .cancel) { send(.editorCancelled) },
            save: ButtonDataModel(
                title: localized("Save", locale),
                systemImage: "checkmark",
                isEnabled: state.isValid,
                accessibilityIdentifier: "saveTask",
                action: { send(.editorSaved) }
            )
        )
    }

    private static func cadenceSection(
        _ state: TaskEditor.State,
        context: PresentationContext,
        edit: @escaping @MainActor (TaskEditor.Action) -> Void
    ) -> CadenceSectionDataModel {
        let locale = context.locale
        let count: StepperDataModel? =
            switch state.cadenceKind {
            case .afterCompletion:
                StepperDataModel(
                    title: localized("Every \(state.everyDays) days", locale),
                    value: state.everyDays,
                    range: 1...365,
                    onChange: { edit(.everyDaysChanged($0)) }
                )
            case .timesPerWeek:
                StepperDataModel(
                    title: localized("\(state.timesPerWeek) times a week", locale),
                    value: state.timesPerWeek,
                    range: 1...7,
                    onChange: { edit(.timesPerWeekChanged($0)) }
                )
            case .weekdays:
                nil
            }
        let weekdays =
            state.cadenceKind == .weekdays
            ? context.calendar.orderedWeekdays(locale: locale).map { day in
                ToggleDataModel(
                    id: day.weekday.rawValue,
                    title: day.name.capitalized(with: locale),
                    isOn: state.weekdays.contains(day.weekday),
                    onChange: { edit(.weekdayToggled(day.weekday, isOn: $0)) }
                )
            }
            : []

        return CadenceSectionDataModel(
            header: localized("Cadence", locale),
            repeats: PickerDataModel(
                title: localized("Repeats", locale),
                options: [
                    .init(id: TaskEditor.CadenceKind.afterCompletion.rawValue, title: localized("After it was last done", locale)),
                    .init(id: TaskEditor.CadenceKind.weekdays.rawValue, title: localized("On fixed days", locale)),
                    .init(id: TaskEditor.CadenceKind.timesPerWeek.rawValue, title: localized("A number of times a week", locale)),
                ],
                selectedID: state.cadenceKind.rawValue,
                onSelect: { id in TaskEditor.CadenceKind(rawValue: id).map { edit(.cadenceKindChanged($0)) } }
            ),
            count: count,
            weekdays: weekdays
        )
    }

    private static func whenItFitsSection(
        _ state: TaskEditor.State,
        locale: Locale,
        edit: @escaping @MainActor (TaskEditor.Action) -> Void
    ) -> WhenItFitsSectionDataModel {
        let requirements = state.task.requirements
        let anywhere = "anywhere"
        let windows: [(Window, String)] = [
            (.morning, localized("Morning", locale)),
            (.workday, localized("Work hours", locale)),
            (.evening, localized("Evening", locale)),
        ]

        return WhenItFitsSectionDataModel(
            header: localized("When it fits", locale),
            location: PickerDataModel(
                title: localized("Where", locale),
                options: [
                    .init(id: anywhere, title: localized("Anywhere", locale)),
                    .init(id: Location.home.rawValue, title: localized("At home", locale)),
                    .init(id: Location.office.rawValue, title: localized("At the office", locale)),
                ],
                selectedID: requirements.location?.rawValue ?? anywhere,
                onSelect: { id in edit(.locationChanged(Location(rawValue: id))) }
            ),
            toggles: windows.map { window, title in
                ToggleDataModel(
                    id: window.rawValue,
                    title: title,
                    isOn: requirements.windows.contains(window),
                    onChange: { edit(.windowToggled(window, isOn: $0)) }
                )
            } + [
                ToggleDataModel(
                    id: "rain",
                    title: localized("Not in the rain", locale),
                    isOn: requirements.avoidedWeather.contains(.rain),
                    onChange: { edit(.avoidsRainToggled($0)) }
                ),
                ToggleDataModel(
                    id: "costsMoney",
                    title: localized("Costs money", locale),
                    isOn: requirements.costsMoney,
                    onChange: { edit(.costsMoneyToggled($0)) }
                ),
            ]
        )
    }

    private static func stepsSection(
        _ state: TaskEditor.State,
        locale: Locale,
        edit: @escaping @MainActor (TaskEditor.Action) -> Void
    ) -> StepsSectionDataModel {
        let steps = state.task.steps
        let stepPrompt = state.trimmedName.isEmpty ? localized("Step name", locale) : state.trimmedName

        return StepsSectionDataModel(
            header: localized("Steps", locale),
            footer: state.showsSuggestion ? localized("Suggested by Tony. Change anything that does not fit.", locale) : nil,
            steps: steps.map { step in
                let minutes = Int(step.duration / 60)
                let gapMinutes = Int(step.minimumGapToNextStep / 60)
                return StepDataModel(
                    id: step.id,
                    name: TextFieldDataModel(
                        title: localized("Step name", locale),
                        text: step.name,
                        prompt: stepPrompt,
                        onChange: { edit(.stepNameChanged(id: step.id, name: $0)) }
                    ),
                    mode: PickerDataModel(
                        title: localized("How", locale),
                        options: [
                            .init(id: Step.Mode.active.rawValue, title: localized("I do it", locale)),
                            .init(id: Step.Mode.background.rawValue, title: localized("It runs on its own", locale)),
                        ],
                        selectedID: step.mode.rawValue,
                        onSelect: { id in Step.Mode(rawValue: id).map { edit(.stepModeChanged(id: step.id, mode: $0)) } }
                    ),
                    duration: StepperDataModel(
                        title: localized("Lasts \(minutes) min", locale),
                        value: minutes,
                        range: 5...480,
                        step: 5,
                        onChange: { edit(.stepMinutesChanged(id: step.id, minutes: $0)) }
                    ),
                    gap: step.id == steps.last?.id
                        ? nil
                        : StepperDataModel(
                            title: localized("Then wait \(gapMinutes) min", locale),
                            value: gapMinutes,
                            range: 0...480,
                            step: 5,
                            onChange: { edit(.stepGapChanged(id: step.id, minutes: $0)) }
                        )
                )
            },
            add: ButtonDataModel(title: localized("Add a step", locale)) { edit(.stepAdded(id: UUID())) },
            canDelete: steps.count > 1,
            move: { source, destination in edit(.stepsMoved(from: source, to: destination)) },
            delete: { offsets in edit(.stepsDeleted(offsets)) }
        )
    }
}
