#if DEBUG
import Foundation
import TonyPresentation
import TonyUIModels

/// Sample data models for the screen previews. Debug builds only: the text is sample data, not translated.
@MainActor
enum PreviewSamples {
    static let check = ButtonDataModel(title: "Mark as done", action: Action("preview") { _ in })

    static func row(_ icon: String, _ title: String, _ subtitle: String, _ status: ChipDataModel, isNeglected: Bool = false) -> TaskRowDataModel {
        TaskRowDataModel(
            id: UUID(),
            icon: icon,
            title: title,
            subtitle: subtitle,
            status: status,
            isNeglected: isNeglected,
            accessibilityIdentifier: title,
            open: {},
            delete: ButtonDataModel(title: "Delete", role: .destructive, action: Action("preview") { _ in })
        )
    }

    static func today(editor: TaskEditorDataModel? = nil, alert: AlertDataModel? = nil) -> TodayScreenDataModel {
        TodayScreenDataModel(
            date: "Thursday, November 12",
            headline: "A light day, Matteo",
            briefing: BriefingDataModel(
                author: "Tony",
                time: "· 8:00",
                text: "Start the laundry before your 10:00 meetings, it runs on its own. The plants have waited 8 days, and the gym is kept for tonight."
            ),
            timelineTitle: "Your day",
            timelineHint: "Suggestions, not orders",
            timeline: [
                .init(id: "now", item: .now(text: "Now · a good moment for Laundry · Wash")),
                .init(
                    id: "laundry",
                    item: .task(
                        .init(
                            icon: "🧺",
                            time: "8:30",
                            title: "Laundry · Wash",
                            reason: "Before your 10:00 meetings. It runs on its own.",
                            actions: ["Later", "Not today"].map { ButtonDataModel(title: $0, action: Action("preview") { _ in }) },
                            check: check
                        ),
                        isLast: false
                    )
                ),
                .init(id: "meetings", item: .meetings(time: "10:00", title: "3 meetings, back to back", detail: "until 11:00")),
                .init(id: "plants", item: .task(.init(icon: "🥀", time: "11:15", title: "Water the plants", reason: "8 days since last time", check: check, isNeglected: true), isLast: false)),
                .init(id: "gym", item: .task(.init(icon: "🏋️", time: "18:00", title: "Gym", reason: "Kept for the evening.", check: check), isLast: true)),
            ],
            addTask: ButtonDataModel(title: "+ Add a task", action: Action("preview") { _ in }),
            tilesTitle: "How things are",
            tiles: [
                .init(id: UUID(), tile: TileDataModel(icon: "🥀", title: "Water the plants", detail: "8 days since last time", isNeglected: true)),
                .init(id: UUID(), tile: TileDataModel(icon: "🏋️", title: "Gym", detail: "2 of 4 this week")),
                .init(id: UUID(), tile: TileDataModel(icon: "🧺", title: "Laundry", detail: "Today")),
                .init(id: UUID(), tile: TileDataModel(icon: "🧹", title: "Vacuum", detail: "In 3 days")),
            ],
            editor: editor,
            dismissEditor: {},
            alert: alert,
            onAppear: {}
        )
    }

    static var emptyToday: TodayScreenDataModel {
        TodayScreenDataModel(
            date: "Saturday, November 14",
            headline: "A free day",
            briefing: BriefingDataModel(author: "Tony", time: "· 9:00", text: "Nothing needs you today. Enjoy it."),
            timelineTitle: "Your day",
            timelineHint: "Suggestions, not orders",
            timeline: [.init(id: "now", item: .now(text: "Now"))],
            addTask: ButtonDataModel(title: "+ Add a task", action: Action("preview") { _ in }),
            tilesTitle: "How things are",
            tiles: [],
            editor: nil,
            dismissEditor: {},
            alert: nil,
            onAppear: {}
        )
    }

    static func tasks(editor: TaskEditorDataModel? = nil) -> TasksScreenDataModel {
        TasksScreenDataModel(
            title: "Tasks",
            add: ButtonDataModel(title: "Add a task", systemImage: "plus", action: Action("preview") { _ in }),
            quickAdd: TextFieldDataModel(title: "Tell Tony what to add", text: "", prompt: "Tell Tony… “water the plants every 5 days”", onChange: { _ in }),
            sections: [
                TaskSectionDataModel(
                    id: "recurring",
                    title: "Recurring",
                    hint: "Top matters most",
                    rows: [
                        row("🧺", "Laundry", "Every 7 days after last time · wash, dry, fold", ChipDataModel(title: "Today")),
                        row("🥀", "Water the plants", "Every 5 days after last time", ChipDataModel(title: "Due", style: .warning), isNeglected: true),
                        row("🗑️", "Take out the trash", "Every Tuesday", ChipDataModel(title: "In 2 days")),
                    ],
                    move: { _, _ in }
                ),
                TaskSectionDataModel(
                    id: "goal",
                    title: "Goals",
                    hint: "Flexible days",
                    rows: [row("🏋️", "Gym", "4 times a week", ChipDataModel(title: "2 / 4"))],
                    move: { _, _ in }
                ),
                TaskSectionDataModel(
                    id: "oneTime",
                    title: "One-time",
                    hint: nil,
                    rows: [row("🛂", "Renew the passport", "By November 30", ChipDataModel(title: "In 18 days"))],
                    move: { _, _ in }
                ),
            ],
            addTask: ButtonDataModel(title: "+ Add a task", action: Action("preview") { _ in }),
            editor: editor,
            dismissEditor: {},
            alert: nil,
            onAppear: {}
        )
    }

    static func step(_ name: String, mode: String, minutes: Int, gap: Int?) -> StepDataModel {
        StepDataModel(
            id: UUID(),
            name: TextFieldDataModel(title: "Step name", text: name, onChange: { _ in }),
            mode: PickerDataModel(
                title: "How",
                options: [.init(id: "active", title: "I do it"), .init(id: "background", title: "It runs on its own")],
                selectedID: mode,
                onSelect: { _ in }
            ),
            duration: StepperDataModel(title: "Lasts \(minutes) min", value: minutes, range: 5...480, step: 5, onChange: { _ in }),
            gap: gap.map { StepperDataModel(title: "Then wait \($0) min", value: $0, range: 0...480, step: 5, onChange: { _ in }) }
        )
    }

    static var taskEditor: TaskEditorDataModel {
        TaskEditorDataModel(
            id: UUID(),
            title: "Edit task",
            name: TextFieldDataModel(title: "Name", text: "Laundry", onChange: { _ in }),
            icon: TextFieldDataModel(title: "Icon", text: "🧺", onChange: { _ in }),
            kind: PickerDataModel(
                title: "Kind",
                options: [.init(id: "recurring", title: "Recurring task"), .init(id: "goal", title: "Goal"), .init(id: "oneTime", title: "One-time task")],
                selectedID: "recurring",
                onSelect: { _ in }
            ),
            cadence: CadenceSectionDataModel(
                header: "Cadence",
                repeats: PickerDataModel(
                    title: "Repeats",
                    options: [.init(id: "afterCompletion", title: "After it was last done"), .init(id: "weekdays", title: "On fixed days")],
                    selectedID: "afterCompletion",
                    onSelect: { _ in }
                ),
                count: StepperDataModel(title: "Every 7 days", value: 7, range: 1...365, onChange: { _ in }),
                weekdays: []
            ),
            whenItFits: WhenItFitsSectionDataModel(
                header: "When it fits",
                location: PickerDataModel(
                    title: "Where",
                    options: [.init(id: "anywhere", title: "Anywhere"), .init(id: "home", title: "At home")],
                    selectedID: "home",
                    onSelect: { _ in }
                ),
                toggles: [
                    ToggleDataModel(id: "morning", title: "Morning", isOn: false, onChange: { _ in }),
                    ToggleDataModel(id: "evening", title: "Evening", isOn: true, onChange: { _ in }),
                ]
            ),
            steps: StepsSectionDataModel(
                header: "Steps",
                footer: "Suggested by Tony. Change anything that does not fit.",
                steps: [
                    step("Load the washing machine", mode: "active", minutes: 10, gap: 0),
                    step("Wash", mode: "background", minutes: 45, gap: 0),
                    step("Fold", mode: "active", minutes: 15, gap: nil),
                ],
                add: ButtonDataModel(title: "Add a step", action: Action("preview") { _ in }),
                canDelete: true,
                move: { _, _ in },
                delete: { _ in }
            ),
            deadline: DeadlineSectionDataModel(
                header: "Deadline",
                toggle: ToggleDataModel(id: "deadline", title: "Must happen by a date", isOn: true, onChange: { _ in }),
                date: DatePickerDataModel(title: "Date", date: .now, onChange: { _ in })
            ),
            delete: ButtonDataModel(title: "Delete task", role: .destructive, action: Action("preview") { _ in }),
            cancel: ButtonDataModel(title: "Cancel", systemImage: "xmark", role: .cancel, action: Action("preview") { _ in }),
            save: ButtonDataModel(title: "Save", systemImage: "checkmark", action: Action("preview") { _ in })
        )
    }

    static func routineEditor(workFooter: String? = nil, descriptionFooter: String? = nil) -> RoutineEditorDataModel {
        let kinds: [PickerDataModel.Option] = [.init(id: "home", title: "At home"), .init(id: "office", title: "At the office"), .init(id: "off", title: "Day off")]
        let week = [("Monday", "home"), ("Tuesday", "office"), ("Wednesday", "home"), ("Thursday", "office"), ("Friday", "home"), ("Saturday", "off"), ("Sunday", "off")]
        func time(_ title: String) -> TimePickerDataModel {
            TimePickerDataModel(title: title, time: .now, onChange: { _ in })
        }
        return RoutineEditorDataModel(
            title: "Your routine",
            name: TextFieldDataModel(title: "Your name", text: "Matteo", onChange: { _ in }),
            description: TextFieldDataModel(
                title: "Describe your week",
                text: descriptionFooter == nil ? "" : "Office on Tuesdays and Thursdays",
                prompt: "Tell Tony… “office on Tuesdays and Thursdays, 9 to 5:30”",
                onChange: { _ in }
            ),
            descriptionFooter: descriptionFooter,
            daysHeader: "Your week",
            days: week.map { day, kind in
                .init(id: day, picker: PickerDataModel(title: day, options: kinds, selectedID: kind, onSelect: { _ in }))
            },
            workHeader: "Work hours",
            workStart: time("Starts"),
            workEnd: time("Ends"),
            workFooter: workFooter,
            sleepHeader: "Sleep",
            wakeTime: time("Up around"),
            bedtime: time("Bed around"),
            cancel: ButtonDataModel(title: "Cancel", systemImage: "xmark", role: .cancel, action: Action("preview") { _ in }),
            save: ButtonDataModel(title: "Save", systemImage: "checkmark", isEnabled: workFooter == nil, action: Action("preview") { _ in })
        )
    }

    static var calendarDebug: CalendarDebugScreenDataModel {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        return CalendarDebugScreenDataModel(
            title: "Calendar check",
            access: "Calendar access: not asked yet",
            requestAccess: ButtonDataModel(title: "Ask for calendar access", action: Action("preview") { _ in }),
            refresh: ButtonDataModel(title: "Read the calendar again", action: Action("preview") { _ in }),
            plannedAt: "Read at 8:00",
            rows: [
                .init(id: start, time: "0:00 to 7:00", detail: "Free · night · home", isBusy: false),
                .init(id: start.addingTimeInterval(1), time: "10:00 to 11:00", detail: "Busy · 3 events merged · workday · home", isBusy: true),
                .init(id: start.addingTimeInterval(2), time: "11:00 to 17:00", detail: "Partly available · workday · home", isBusy: false),
            ],
            onAppear: {}
        )
    }

    static var modelCheck: ModelCheckScreenDataModel {
        ModelCheckScreenDataModel(
            title: "Model check",
            availability: "Model: available",
            run: ButtonDataModel(title: "Run the evaluation set", action: Action("preview") { _ in }),
            report: "Tony model evaluation\niOS 27.2 · iPhone · 2026-11-15\n\nBriefings (en): 9 of 10 pass · median 1.84 s · slowest 2.71 s\n\nTotal: 50 of 52 pass (96%)",
            shareReport: "Share the report",
            rows: [
                .init(id: "B1 en", title: "B1 en", input: "Tuesday 10 November\n08:00 Water the plants. The first moment that fits.", output: "Start with the plants at 8:00.", verdict: "pass · 1.84 s", hasPassed: true),
                .init(id: "T1 en", title: "T1 en", input: "Water the plants every 5 days", output: "Water · no cadence", verdict: "fail · 0.92 s · name has no \"plants\"", hasPassed: false),
                .init(id: "R1 en", title: "R1 en", input: "I work at the office on Tuesdays and Thursdays", output: nil, verdict: "not run", hasPassed: nil),
            ],
            extensionChecks: ["Widget: has not run yet", "Background task: has not run yet"],
            requestBackgroundCheck: ButtonDataModel(title: "Ask iOS for a background check", action: Action("preview") { _ in }),
            backgroundCheckRequest: nil,
            onAppear: {}
        )
    }
}
#endif
