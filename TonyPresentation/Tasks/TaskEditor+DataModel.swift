import Foundation
import TonyCore
import TonyUIModels

extension TaskEditor {
    /// The form for this state. The feature that shows it decides what cancelling, saving and deleting do.
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
        let task = state.task

        return TaskEditorDataModel(
            id: task.id,
            title: state.isNew ? localized("New task", locale) : localized("Edit task", locale),
            name: TextFieldDataModel(
                title: localized("Name", locale),
                text: task.name,
                accessibilityIdentifier: "taskName",
                onChange: TonyUIModels.Action(id: "nameChanged") { edit(.nameChanged($0)) }
            ),
            icon: TextFieldDataModel(title: localized("Icon", locale), text: task.icon, onChange: TonyUIModels.Action(id: "iconChanged") { edit(.iconChanged($0)) }),
            kind: PickerDataModel(
                title: localized("Kind", locale),
                options: [
                    .init(id: TonyTask.Kind.recurring.rawValue, title: localized("Recurring task", locale)),
                    .init(id: TonyTask.Kind.goal.rawValue, title: localized("Goal", locale)),
                    .init(id: TonyTask.Kind.oneTime.rawValue, title: localized("One-time task", locale)),
                ],
                selectedID: task.kind.rawValue,
                onSelect: TonyUIModels.Action(id: "kindChanged") { id in TonyTask.Kind(rawValue: id).map { edit(.kindChanged($0)) } }
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
                    onChange: TonyUIModels.Action(id: "deadlineToggled") { edit(.deadlineToggled($0)) }
                ),
                date: state.hasDeadline
                    ? DatePickerDataModel(title: localized("Date", locale), date: state.deadline, onChange: TonyUIModels.Action(id: "deadlineChanged") { edit(.deadlineChanged($0)) })
                    : nil
            ),
            delete: state.isNew
                ? nil
                : ButtonDataModel(
                    title: localized("Delete task", locale),
                    role: .destructive,
                    accessibilityIdentifier: "deleteTask",
                    action: delete
                ),
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

    private static func cadenceSection(
        _ state: State,
        context: PresentationContext,
        edit: @escaping @MainActor (Action) -> Void
    ) -> CadenceSectionDataModel {
        let locale = context.locale
        let count: StepperDataModel? =
            switch state.cadenceKind {
            case .afterCompletion:
                StepperDataModel(
                    title: localized("Every \(state.everyDays) days", locale),
                    value: state.everyDays,
                    range: 1...365,
                    onChange: TonyUIModels.Action(id: "everyDaysChanged") { edit(.everyDaysChanged($0)) }
                )
            case .timesPerWeek:
                StepperDataModel(
                    title: localized("\(state.timesPerWeek) times a week", locale),
                    value: state.timesPerWeek,
                    range: 1...7,
                    onChange: TonyUIModels.Action(id: "timesPerWeekChanged") { edit(.timesPerWeekChanged($0)) }
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
                    onChange: TonyUIModels.Action(id: "weekdayToggled", parameters: day.weekday) { weekday, isOn in edit(.weekdayToggled(weekday, isOn: isOn)) }
                )
            }
            : []

        return CadenceSectionDataModel(
            header: localized("Cadence", locale),
            repeats: PickerDataModel(
                title: localized("Repeats", locale),
                options: [
                    .init(id: CadenceKind.afterCompletion.rawValue, title: localized("After it was last done", locale)),
                    .init(id: CadenceKind.weekdays.rawValue, title: localized("On fixed days", locale)),
                    .init(id: CadenceKind.timesPerWeek.rawValue, title: localized("A number of times a week", locale)),
                ],
                selectedID: state.cadenceKind.rawValue,
                onSelect: TonyUIModels.Action(id: "cadenceKindChanged") { id in CadenceKind(rawValue: id).map { edit(.cadenceKindChanged($0)) } }
            ),
            count: count,
            weekdays: weekdays
        )
    }

    private static func whenItFitsSection(
        _ state: State,
        locale: Locale,
        edit: @escaping @MainActor (Action) -> Void
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
                onSelect: TonyUIModels.Action(id: "locationChanged") { id in edit(.locationChanged(Location(rawValue: id))) }
            ),
            toggles: windows.map { window, title in
                ToggleDataModel(
                    id: window.rawValue,
                    title: title,
                    isOn: requirements.windows.contains(window),
                    onChange: TonyUIModels.Action(id: "windowToggled", parameters: window) { window, isOn in edit(.windowToggled(window, isOn: isOn)) }
                )
            } + [
                ToggleDataModel(
                    id: "rain",
                    title: localized("Not in the rain", locale),
                    isOn: requirements.avoidedWeather.contains(.rain),
                    onChange: TonyUIModels.Action(id: "avoidsRainToggled") { edit(.avoidsRainToggled($0)) }
                ),
                ToggleDataModel(
                    id: "costsMoney",
                    title: localized("Costs money", locale),
                    isOn: requirements.costsMoney,
                    onChange: TonyUIModels.Action(id: "costsMoneyToggled") { edit(.costsMoneyToggled($0)) }
                ),
            ]
        )
    }

    private static func stepsSection(
        _ state: State,
        locale: Locale,
        edit: @escaping @MainActor (Action) -> Void
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
                        onChange: TonyUIModels.Action(id: "stepNameChanged", parameters: step.id) { id, name in edit(.stepNameChanged(id: id, name: name)) }
                    ),
                    mode: PickerDataModel(
                        title: localized("How", locale),
                        options: [
                            .init(id: Step.Mode.active.rawValue, title: localized("I do it", locale)),
                            .init(id: Step.Mode.background.rawValue, title: localized("It runs on its own", locale)),
                        ],
                        selectedID: step.mode.rawValue,
                        onSelect: TonyUIModels.Action(id: "stepModeChanged", parameters: step.id) { stepID, mode in
                            Step.Mode(rawValue: mode).map { edit(.stepModeChanged(id: stepID, mode: $0)) }
                        }
                    ),
                    duration: StepperDataModel(
                        title: localized("Lasts \(minutes) min", locale),
                        value: minutes,
                        range: 5...480,
                        step: 5,
                        onChange: TonyUIModels.Action(id: "stepMinutesChanged", parameters: step.id) { id, minutes in edit(.stepMinutesChanged(id: id, minutes: minutes)) }
                    ),
                    gap: step.id == steps.last?.id
                        ? nil
                        : StepperDataModel(
                            title: localized("Then wait \(gapMinutes) min", locale),
                            value: gapMinutes,
                            range: 0...480,
                            step: 5,
                            onChange: TonyUIModels.Action(id: "stepGapChanged", parameters: step.id) { id, minutes in edit(.stepGapChanged(id: id, minutes: minutes)) }
                        )
                )
            },
            add: ButtonDataModel(title: localized("Add a step", locale), action: TonyUIModels.Action(id: "add_step") { _ in edit(.stepAdded(id: UUID())) }),
            canDelete: steps.count > 1,
            move: TonyUIModels.Action(id: "stepsMoved") { move in edit(.stepsMoved(from: move.source, to: move.destination)) },
            delete: TonyUIModels.Action(id: "stepsDeleted") { edit(.stepsDeleted($0)) }
        )
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
