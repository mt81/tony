import Foundation
import MemberwiseInit
import TonyUIModels

@MemberwiseInit(.public)
public struct TasksScreenDataModel {
    public var title: String
    public var add: ButtonDataModel
    /// Where a task is typed in plain words. Return reads it and opens the form, filled in.
    public var quickAdd: TextFieldDataModel
    public var sections: [TaskSectionDataModel]
    public var addTask: ButtonDataModel
    public var editor: TaskEditorDataModel?
    public var dismissEditor: any Executable<Void>
    public var alert: AlertDataModel?
    public var onAppear: any Executable<Void>
}

@MemberwiseInit(.public)
public struct TaskSectionDataModel: Identifiable {
    public var id: String
    public var title: String
    public var hint: String?
    public var rows: [TaskRowDataModel]
    public var move: any Executable<Move>
}

@MemberwiseInit(.public)
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
}

@MemberwiseInit(.public)
public struct CadenceSectionDataModel {
    public var header: String
    public var repeats: PickerDataModel
    /// The number of days or of times a week; nil on fixed days.
    public var count: StepperDataModel?
    /// One toggle per weekday on fixed days; empty otherwise.
    public var weekdays: [ToggleDataModel]
}

@MemberwiseInit(.public)
public struct WhenItFitsSectionDataModel {
    public var header: String
    public var location: PickerDataModel
    public var toggles: [ToggleDataModel]
}

@MemberwiseInit(.public)
public struct StepsSectionDataModel {
    public var header: String
    public var footer: String?
    public var steps: [StepDataModel]
    public var add: ButtonDataModel
    /// The last step cannot be deleted.
    public var canDelete: Bool
    public var move: any Executable<Move>
    public var delete: any Executable<IndexSet>
}

@MemberwiseInit(.public)
public struct StepDataModel: Identifiable {
    public var id: UUID
    public var name: TextFieldDataModel
    public var mode: PickerDataModel
    public var duration: StepperDataModel
    /// Nil for the last step.
    public var gap: StepperDataModel?
}

@MemberwiseInit(.public)
public struct DeadlineSectionDataModel {
    public var header: String
    public var toggle: ToggleDataModel
    public var date: DatePickerDataModel?
}
