import Foundation

public struct TasksScreenDataModel {
    public var title: String
    public var add: ButtonDataModel
    public var sections: [TaskSectionDataModel]
    public var addTask: ButtonDataModel
    public var editor: TaskEditorDataModel?
    public var dismissEditor: @MainActor () -> Void
    public var alert: AlertDataModel?
    public var onAppear: @MainActor () -> Void

    public init(
        title: String,
        add: ButtonDataModel,
        sections: [TaskSectionDataModel],
        addTask: ButtonDataModel,
        editor: TaskEditorDataModel?,
        dismissEditor: @escaping @MainActor () -> Void,
        alert: AlertDataModel?,
        onAppear: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.add = add
        self.sections = sections
        self.addTask = addTask
        self.editor = editor
        self.dismissEditor = dismissEditor
        self.alert = alert
        self.onAppear = onAppear
    }
}

public struct TaskSectionDataModel: Identifiable {
    public var id: String
    public var title: String
    public var hint: String?
    public var rows: [TaskRowDataModel]
    public var move: @MainActor (IndexSet, Int) -> Void

    public init(
        id: String,
        title: String,
        hint: String?,
        rows: [TaskRowDataModel],
        move: @escaping @MainActor (IndexSet, Int) -> Void
    ) {
        self.id = id
        self.title = title
        self.hint = hint
        self.rows = rows
        self.move = move
    }
}

public struct TaskEditorDataModel: Identifiable {
    public var id: UUID
    public var title: String
    public var name: TextFieldDataModel
    public var icon: TextFieldDataModel
    public var kind: PickerDataModel
    /// Nil for a one-time task.
    public var cadence: CadenceSectionDataModel?
    public var whenItFits: WhenItFitsSectionDataModel
    public var steps: StepsSectionDataModel
    public var deadline: DeadlineSectionDataModel
    /// Nil for a task that is not saved yet.
    public var delete: ButtonDataModel?
    public var cancel: ButtonDataModel
    public var save: ButtonDataModel

    public init(
        id: UUID,
        title: String,
        name: TextFieldDataModel,
        icon: TextFieldDataModel,
        kind: PickerDataModel,
        cadence: CadenceSectionDataModel?,
        whenItFits: WhenItFitsSectionDataModel,
        steps: StepsSectionDataModel,
        deadline: DeadlineSectionDataModel,
        delete: ButtonDataModel?,
        cancel: ButtonDataModel,
        save: ButtonDataModel
    ) {
        self.id = id
        self.title = title
        self.name = name
        self.icon = icon
        self.kind = kind
        self.cadence = cadence
        self.whenItFits = whenItFits
        self.steps = steps
        self.deadline = deadline
        self.delete = delete
        self.cancel = cancel
        self.save = save
    }
}

public struct CadenceSectionDataModel {
    public var header: String
    public var repeats: PickerDataModel
    /// The number of days or of times a week; nil on fixed days.
    public var count: StepperDataModel?
    /// One toggle per weekday on fixed days; empty otherwise.
    public var weekdays: [ToggleDataModel]

    public init(
        header: String,
        repeats: PickerDataModel,
        count: StepperDataModel?,
        weekdays: [ToggleDataModel]
    ) {
        self.header = header
        self.repeats = repeats
        self.count = count
        self.weekdays = weekdays
    }
}

public struct WhenItFitsSectionDataModel {
    public var header: String
    public var location: PickerDataModel
    public var toggles: [ToggleDataModel]

    public init(
        header: String,
        location: PickerDataModel,
        toggles: [ToggleDataModel]
    ) {
        self.header = header
        self.location = location
        self.toggles = toggles
    }
}

public struct StepsSectionDataModel {
    public var header: String
    public var footer: String?
    public var steps: [StepDataModel]
    public var add: ButtonDataModel
    /// The last step cannot be deleted.
    public var canDelete: Bool
    public var move: @MainActor (IndexSet, Int) -> Void
    public var delete: @MainActor (IndexSet) -> Void

    public init(
        header: String,
        footer: String?,
        steps: [StepDataModel],
        add: ButtonDataModel,
        canDelete: Bool,
        move: @escaping @MainActor (IndexSet, Int) -> Void,
        delete: @escaping @MainActor (IndexSet) -> Void
    ) {
        self.header = header
        self.footer = footer
        self.steps = steps
        self.add = add
        self.canDelete = canDelete
        self.move = move
        self.delete = delete
    }
}

public struct StepDataModel: Identifiable {
    public var id: UUID
    public var name: TextFieldDataModel
    public var mode: PickerDataModel
    public var duration: StepperDataModel
    /// Nil for the last step.
    public var gap: StepperDataModel?

    public init(
        id: UUID,
        name: TextFieldDataModel,
        mode: PickerDataModel,
        duration: StepperDataModel,
        gap: StepperDataModel?
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.duration = duration
        self.gap = gap
    }
}

public struct DeadlineSectionDataModel {
    public var header: String
    public var toggle: ToggleDataModel
    public var date: DatePickerDataModel?

    public init(
        header: String,
        toggle: ToggleDataModel,
        date: DatePickerDataModel?
    ) {
        self.header = header
        self.toggle = toggle
        self.date = date
    }
}
