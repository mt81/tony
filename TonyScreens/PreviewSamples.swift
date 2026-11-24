#if DEBUG
import Foundation
import TonyPresentation
import TonyUIModels

/// Sample data models for the screen previews. Debug builds only: the text is sample data, not translated.
@MainActor
enum PreviewSamples {
    static let check = ButtonDataModel(title: "Mark as done", action: Action(id: "preview") { _ in })

    static func row(_ icon: String, _ title: String, _ subtitle: String, _ status: ChipDataModel, isNeglected: Bool = false) -> TaskRowDataModel {
        TaskRowDataModel(
            id: UUID(),
            icon: icon,
            title: title,
            subtitle: subtitle,
            status: status,
            isNeglected: isNeglected,
            accessibilityIdentifier: title,
            open: Action(id: "preview") { _ in },
            delete: ButtonDataModel(title: "Delete", role: .destructive, action: Action(id: "preview") { _ in })
        )
    }

    static func today(editor: TaskEditorDataModel? = nil, alert: AlertDataModel? = nil) -> TodayScreenDataModel {
        TodayScreenDataModel(
            date: "Thursday, November 12",
            headline: "A light day, Matteo",
            briefing: "Start the laundry before your 10:00 meetings, it runs on its own. The plants have waited 8 days, and the gym is kept for tonight.",
            timelineTitle: "Your day",
            timeline: [
                .init(id: "done", item: .done(text: "Good job, today you already did Supplements and Grocery.")),
                .init(
                    id: "laundry",
                    item: .task(
                        .init(
                            icon: "🧺",
                            time: "8:30",
                            title: "Laundry · Wash",
                            reason: "Before your 10:00 meetings. It runs on its own.",
                            actions: ["Later", "Not today"].map { ButtonDataModel(title: $0, action: Action(id: "preview") { _ in }) },
                            check: check,
                            now: "8:30 · a good moment to start"
                        ),
                        isLast: false
                    )
                ),
                .init(id: "meetings", item: .meetings(time: "10:00", title: "3 meetings, back to back", detail: "until 11:00")),
                .init(id: "plants", item: .task(.init(icon: "🥀", time: "11:15", title: "Water the plants", reason: "8 days since last time", check: check, isNeglected: true), isLast: false)),
                .init(id: "gym", item: .task(.init(icon: "🏋️", time: "18:00", title: "Gym", reason: "Kept for the evening.", check: check), isLast: true)),
            ],
            tilesTitle: "How things are",
            tiles: [
                .init(id: UUID(), tile: TileDataModel(icon: "🥀", title: "Water the plants", detail: "8 days since last time", colour: .green, isNeglected: true)),
                .init(id: UUID(), tile: TileDataModel(icon: "🏋️", title: "Gym", detail: "2 of 4 this week", colour: .orange)),
                .init(id: UUID(), tile: TileDataModel(icon: "🧺", title: "Laundry", detail: "Today", colour: .yellow)),
                .init(id: UUID(), tile: TileDataModel(icon: "🧹", title: "Vacuum", detail: "In 3 days", colour: .blue)),
            ],
            editor: editor,
            dismissEditor: Action(id: "preview") { _ in },
            alert: alert,
            onAppear: Action(id: "preview") { _ in }
        )
    }

    static var emptyToday: TodayScreenDataModel {
        TodayScreenDataModel(
            date: "Saturday, November 14",
            headline: "A free day",
            briefing: "Nothing needs you today. Enjoy it.",
            timelineTitle: "Your day",
            timeline: [.init(id: "now", item: .now(text: "Now"))],
            tilesTitle: "How things are",
            tiles: [],
            editor: nil,
            dismissEditor: Action(id: "preview") { _ in },
            alert: nil,
            onAppear: Action(id: "preview") { _ in }
        )
    }

    static func tasks(editor: TaskEditorDataModel? = nil) -> TasksScreenDataModel {
        TasksScreenDataModel(
            title: "Tasks",
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
                    move: Action(id: "preview") { _ in }
                ),
                TaskSectionDataModel(
                    id: "goal",
                    title: "Goals",
                    hint: "Flexible days",
                    rows: [row("🏋️", "Gym", "4 times a week", ChipDataModel(title: "2 / 4"))],
                    move: Action(id: "preview") { _ in }
                ),
                TaskSectionDataModel(
                    id: "oneTime",
                    title: "One-time",
                    hint: nil,
                    rows: [row("🛂", "Renew the passport", "By November 30", ChipDataModel(title: "In 18 days"))],
                    move: Action(id: "preview") { _ in }
                ),
            ],
            editor: editor,
            dismissEditor: Action(id: "preview") { _ in },
            alert: nil,
            onAppear: Action(id: "preview") { _ in }
        )
    }

    static let noAction = Action(id: "preview") { (_: Void) in }

    static func row(_ systemImage: String, _ title: String, _ value: String) -> DetailRowDataModel {
        DetailRowDataModel(systemImage: systemImage, title: title, value: value)
    }

    static func picker(_ title: String, _ options: [String], selected: String) -> PickerDataModel {
        PickerDataModel(title: title, options: options.map { .init(id: $0, title: $0) }, selectedID: selected, onSelect: Action(id: "preview") { _ in })
    }

    static func checklist(_ titles: [String], on: Set<String>) -> [ToggleDataModel] {
        titles.map { ToggleDataModel(id: $0, title: $0, isOn: on.contains($0), onChange: Action(id: "preview") { _ in }) }
    }

    static func subtask(_ name: String, minutes: Int) -> SubtaskDataModel {
        SubtaskDataModel(
            id: UUID(),
            name: TextFieldDataModel(title: "Sub task", text: name, onChange: Action(id: "preview") { _ in }),
            duration: picker("Duration", ["5 min", "10 min", "15 min", "30 min", "45 min", "1 hr"], selected: "\(minutes) min")
        )
    }

    static var taskComposer: TaskEditorDataModel {
        TaskEditorDataModel(
            id: UUID(),
            title: "New task",
            composer: TaskComposerDataModel(
                prompt: "Describe your task",
                composer: ComposerDataModel(
                    text: TextFieldDataModel(
                        title: "Describe your task",
                        text: "Do dark clothes laundry every two weeks",
                        prompt: "Water the plants every 5 days",
                        onChange: Action(id: "preview") { _ in }
                    ),
                    send: ButtonDataModel(title: "Send", systemImage: "arrow.up", action: noAction),
                    isSending: false
                )
            ),
            cancel: ButtonDataModel(title: "Cancel", systemImage: "xmark", role: .cancel, action: noAction),
            save: ButtonDataModel(title: "Save", systemImage: "checkmark", isEnabled: false, action: noAction)
        )
    }

    static var taskEditor: TaskEditorDataModel {
        TaskEditorDataModel(
            id: UUID(),
            title: "New task",
            form: TaskFormDataModel(
                icon: TextFieldDataModel(title: "Icon", text: "🧺", onChange: Action(id: "preview") { _ in }),
                name: TextFieldDataModel(title: "Name", text: "Dark clothes laundry", onChange: Action(id: "preview") { _ in }),
                scheduleHeader: "Schedule",
                repeats: RepeatsDataModel(
                    row: row("repeat", "Repeats", "Every 2 weeks"),
                    choices: picker("Repeats", ["Never", "Every day", "Weekdays", "Every week", "Every 2 weeks", "Every month", "Every year", "Times a week", "Custom"], selected: "Every 2 weeks")
                ),
                countedFrom: CountedFromDataModel(
                    row: row("checkmark.circle", "Counted from", "Last time done"),
                    choices: picker("Counted from", ["Last time done", "Fixed schedule"], selected: "Last time done")
                ),
                deadline: DeadlineDataModel(
                    row: row("calendar", "Deadline", "None"),
                    toggle: ToggleDataModel(id: "deadline", title: "Must happen by a date", isOn: false, onChange: Action(id: "preview") { _ in })
                ),
                whenItFitsHeader: "When it fits",
                location: ChoiceDataModel(row: row("location", "Where", "At home"), choices: picker("Where", ["Anywhere", "At home", "At the office"], selected: "At home")),
                timeOfDay: ChecklistDataModel(row: row("clock", "Time of day", "Any time"), items: checklist(["Any time", "Morning", "Work hours", "Evening"], on: ["Any time"])),
                weather: ChecklistDataModel(row: row("cloud.rain", "Weather", "Any weather"), items: checklist(["Any weather", "Not in the rain", "Not in the snow"], on: ["Any weather"])),
                subtasks: SubtasksSectionDataModel(
                    header: "Sub tasks",
                    subtasks: [subtask("Load the washing machine", minutes: 10), subtask("Hang to dry", minutes: 15), subtask("Fold", minutes: 15)],
                    add: ButtonDataModel(title: "Add a sub task", systemImage: "plus", action: noAction),
                    canDelete: true,
                    move: Action(id: "preview") { _ in },
                    delete: Action(id: "preview") { _ in }
                )
            ),
            cancel: ButtonDataModel(title: "Cancel", systemImage: "xmark", role: .cancel, action: noAction),
            save: ButtonDataModel(title: "Save", systemImage: "checkmark", action: noAction)
        )
    }

    static func routineEditor(workFooter: String? = nil, descriptionFooter: String? = nil) -> RoutineEditorDataModel {
        let kinds: [PickerDataModel.Option] = [.init(id: "home", title: "At home"), .init(id: "office", title: "At the office"), .init(id: "off", title: "Day off")]
        let week = [("Monday", "home"), ("Tuesday", "office"), ("Wednesday", "home"), ("Thursday", "office"), ("Friday", "home"), ("Saturday", "off"), ("Sunday", "off")]
        func time(_ title: String) -> TimePickerDataModel {
            TimePickerDataModel(title: title, time: .now, onChange: Action(id: "preview") { _ in })
        }
        return RoutineEditorDataModel(
            title: "Your routine",
            name: TextFieldDataModel(title: "Your name", text: "Matteo", onChange: Action(id: "preview") { _ in }),
            description: TextFieldDataModel(
                title: "Describe your week",
                text: descriptionFooter == nil ? "" : "Office on Tuesdays and Thursdays",
                prompt: "Tell Tony… “office on Tuesdays and Thursdays, 9 to 5:30”",
                onChange: Action(id: "preview") { _ in }
            ),
            descriptionFooter: descriptionFooter,
            daysHeader: "Your week",
            days: week.map { day, kind in
                .init(id: day, picker: PickerDataModel(title: day, options: kinds, selectedID: kind, onSelect: Action(id: "preview") { _ in }))
            },
            workHeader: "Work hours",
            workStart: time("Starts"),
            workEnd: time("Ends"),
            workFooter: workFooter,
            sleepHeader: "Sleep",
            wakeTime: time("Up around"),
            bedtime: time("Bed around"),
            cancel: ButtonDataModel(title: "Cancel", systemImage: "xmark", role: .cancel, action: Action(id: "preview") { _ in }),
            save: ButtonDataModel(title: "Save", systemImage: "checkmark", isEnabled: workFooter == nil, action: Action(id: "preview") { _ in })
        )
    }

    static var calendarDebug: CalendarDebugScreenDataModel {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        return CalendarDebugScreenDataModel(
            title: "Calendar check",
            access: "Calendar access: not asked yet",
            weather: "Weather today in Paris: rain",
            places: [
                ButtonDataModel(title: "Use Paris", accessibilityIdentifier: "placeParis", action: Action(id: "preview") { _ in }),
                ButtonDataModel(title: "Clear the city", accessibilityIdentifier: "clearPlace", action: Action(id: "preview") { _ in }),
            ],
            requestAccess: ButtonDataModel(title: "Ask for calendar access", action: Action(id: "preview") { _ in }),
            refresh: ButtonDataModel(title: "Read the calendar again", action: Action(id: "preview") { _ in }),
            plannedAt: "Read at 8:00",
            rows: [
                .init(id: start, time: "0:00 to 7:00", detail: "Free · night · home", isBusy: false),
                .init(id: start.addingTimeInterval(1), time: "10:00 to 11:00", detail: "Busy · 3 events merged · workday · home", isBusy: true),
                .init(id: start.addingTimeInterval(2), time: "11:00 to 17:00", detail: "Partly available · workday · home", isBusy: false),
            ],
            onAppear: Action(id: "preview") { _ in }
        )
    }

    static var modelCheck: ModelCheckScreenDataModel {
        ModelCheckScreenDataModel(
            title: "Model check",
            availability: "Model: available",
            run: ButtonDataModel(title: "Run the evaluation set", action: Action(id: "preview") { _ in }),
            report: "Tony model evaluation\niOS 27.2 · iPhone · 2026-11-15\n\nBriefings (en): 9 of 10 pass · median 1.84 s · slowest 2.71 s\n\nTotal: 50 of 52 pass (96%)",
            shareReport: "Share the report",
            rows: [
                .init(id: "B1 en", title: "B1 en", input: "Tuesday 10 November\n08:00 Water the plants. The first moment that fits.", output: "Start with the plants at 8:00.", verdict: "pass · 1.84 s", hasPassed: true),
                .init(id: "T1 en", title: "T1 en", input: "Water the plants every 5 days", output: "Water · no cadence", verdict: "fail · 0.92 s · name has no \"plants\"", hasPassed: false),
                .init(id: "R1 en", title: "R1 en", input: "I work at the office on Tuesdays and Thursdays", output: nil, verdict: "not run", hasPassed: nil),
            ],
            extensionChecks: ["Widget: has not run yet", "Background task: has not run yet"],
            requestBackgroundCheck: ButtonDataModel(title: "Ask iOS for a background check", action: Action(id: "preview") { _ in }),
            backgroundCheckRequest: nil,
            onAppear: Action(id: "preview") { _ in }
        )
    }
}
#endif
