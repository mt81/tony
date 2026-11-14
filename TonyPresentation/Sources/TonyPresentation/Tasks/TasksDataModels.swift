import Foundation
import TonyUIKit

public struct TasksScreenDataModel {
    public var title: String
    public var add: ButtonDataModel
    public var sections: [TaskSectionDataModel]
    public var addTask: ButtonDataModel
    public var editor: TaskEditorDataModel?
    public var dismissEditor: @MainActor () -> Void
    public var alert: AlertDataModel?
    public var onAppear: @MainActor () -> Void
}

public struct TaskSectionDataModel: Identifiable {
    public var id: String
    public var title: String
    public var hint: String?
    public var rows: [TaskRowDataModel]
    public var move: @MainActor (IndexSet, Int) -> Void
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
}

public struct CadenceSectionDataModel {
    public var header: String
    public var repeats: PickerDataModel
    /// The number of days or of times a week; nil on fixed days.
    public var count: StepperDataModel?
    /// One toggle per weekday on fixed days; empty otherwise.
    public var weekdays: [ToggleDataModel]
}

public struct WhenItFitsSectionDataModel {
    public var header: String
    public var location: PickerDataModel
    public var toggles: [ToggleDataModel]
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
}

public struct StepDataModel: Identifiable {
    public var id: UUID
    public var name: TextFieldDataModel
    public var mode: PickerDataModel
    public var duration: StepperDataModel
    /// Nil for the last step.
    public var gap: StepperDataModel?
}

public struct DeadlineSectionDataModel {
    public var header: String
    public var toggle: ToggleDataModel
    public var date: DatePickerDataModel?
}
