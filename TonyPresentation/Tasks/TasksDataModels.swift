import Foundation
import MemberwiseInit
import TonyUIModels

@MemberwiseInit(.public)
public struct TasksScreenDataModel {
    public var title: String
    public var add: ButtonDataModel
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

/// The task sheet: the composer for a new task, then the form.
@MemberwiseInit(.public)
public struct TaskEditorDataModel: Identifiable, Equatable {
    public var id: UUID
    public var title: String
    /// While the task is typed in one sentence; nil once the form shows.
    public var composer: TaskComposerDataModel? = nil
    /// Once the sentence is read, or for a task that exists; nil while composing.
    public var form: TaskFormDataModel? = nil
    public var cancel: ButtonDataModel
    public var save: ButtonDataModel
}

@MemberwiseInit(.public)
public struct TaskComposerDataModel: Equatable {
    public var prompt: String
    public var composer: ComposerDataModel
}

@MemberwiseInit(.public)
public struct TaskFormDataModel: Equatable {
    public var icon: TextFieldDataModel
    public var name: TextFieldDataModel
    public var scheduleHeader: String
    public var repeats: RepeatsDataModel
    /// Nil unless the task repeats at an interval.
    public var countedFrom: CountedFromDataModel? = nil
    public var deadline: DeadlineDataModel
    public var whenItFitsHeader: String
    public var location: ChoiceDataModel
    public var timeOfDay: ChecklistDataModel
    public var weather: ChecklistDataModel
    public var subtasks: SubtasksSectionDataModel
    /// Nil for a task that is not saved yet.
    public var delete: ButtonDataModel? = nil
}

/// The Repeats row and its page.
@MemberwiseInit(.public)
public struct RepeatsDataModel: Equatable {
    public var row: DetailRowDataModel
    public var choices: PickerDataModel
    /// Nil unless the task is a number of times a week.
    public var timesPerWeek: StepperDataModel? = nil
    /// Nil unless Custom is picked.
    public var custom: CustomRepeatDataModel? = nil
}

@MemberwiseInit(.public)
public struct CustomRepeatDataModel: Equatable {
    public var header: String
    public var frequency: PickerDataModel
    /// Nil once weekdays are picked: they repeat every week.
    public var count: StepperDataModel?
    /// One toggle per weekday for a weekly frequency; empty otherwise.
    public var weekdays: [ToggleDataModel]
}

@MemberwiseInit(.public)
public struct CountedFromDataModel: Equatable {
    public var row: DetailRowDataModel
    public var choices: PickerDataModel
    /// Nil unless the task is on a fixed schedule.
    public var start: DatePickerDataModel? = nil
}

@MemberwiseInit(.public)
public struct DeadlineDataModel: Equatable {
    public var row: DetailRowDataModel
    public var toggle: ToggleDataModel
    public var date: DatePickerDataModel? = nil
}

/// A row whose page picks one value.
@MemberwiseInit(.public)
public struct ChoiceDataModel: Equatable {
    public var row: DetailRowDataModel
    public var choices: PickerDataModel
}

/// A row whose page checks any number of values.
@MemberwiseInit(.public)
public struct ChecklistDataModel: Equatable {
    public var row: DetailRowDataModel
    public var items: [ToggleDataModel]
}

@MemberwiseInit(.public)
public struct SubtasksSectionDataModel {
    public var header: String
    public var subtasks: [SubtaskDataModel]
    public var add: ButtonDataModel
    /// The last one cannot be deleted.
    public var canDelete: Bool
    public var move: any Executable<Move>
    public var delete: any Executable<IndexSet>
}

@MemberwiseInit(.public)
public struct SubtaskDataModel: Identifiable, Equatable {
    public var id: UUID
    public var name: TextFieldDataModel
    public var duration: PickerDataModel
}

extension TasksScreenDataModel: Equatable {
    public static func == (lhs: TasksScreenDataModel, rhs: TasksScreenDataModel) -> Bool {
        lhs.title == rhs.title
            && lhs.add == rhs.add
            && lhs.sections == rhs.sections
            && lhs.addTask == rhs.addTask
            && lhs.editor == rhs.editor
            && lhs.alert == rhs.alert
            && lhs.dismissEditor.isEqual(to: rhs.dismissEditor)
            && lhs.onAppear.isEqual(to: rhs.onAppear)
    }
}

extension TaskSectionDataModel: Equatable {
    public static func == (lhs: TaskSectionDataModel, rhs: TaskSectionDataModel) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.hint == rhs.hint
            && lhs.rows == rhs.rows
            && lhs.move.isEqual(to: rhs.move)
    }
}

extension SubtasksSectionDataModel: Equatable {
    public static func == (lhs: SubtasksSectionDataModel, rhs: SubtasksSectionDataModel) -> Bool {
        lhs.header == rhs.header
            && lhs.subtasks == rhs.subtasks
            && lhs.add == rhs.add
            && lhs.canDelete == rhs.canDelete
            && lhs.move.isEqual(to: rhs.move)
            && lhs.delete.isEqual(to: rhs.delete)
    }
}
