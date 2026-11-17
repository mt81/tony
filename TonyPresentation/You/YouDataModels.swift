import Foundation
import MemberwiseInit
import TonyUIModels

/// The You tab: who the user is, their routine and what Tony may read. The rest of the tab comes with C25.
@MemberwiseInit(.public)
public struct YouScreenDataModel {
    /// The first letter of the name; nil when there is no name.
    public var initial: String?
    public var name: String
    public var routine: RoutineCardDataModel
    public var calendar: CalendarCardDataModel
    public var editor: RoutineEditorDataModel?
    public var dismissEditor: @MainActor () -> Void
    public var alert: AlertDataModel?
    public var onAppear: @MainActor () -> Void
}

/// The usual week in a few lines, with the button that opens its form.
@MemberwiseInit(.public)
public struct RoutineCardDataModel {
    public var title: String
    public var edit: ButtonDataModel
    public var lines: [String]
}

/// Where calendar access stands, and the button that asks for it while it has not been asked.
@MemberwiseInit(.public)
public struct CalendarCardDataModel {
    public var title: String
    public var text: String
    public var allow: ButtonDataModel?
}

/// The form for the name and the usual week.
@MemberwiseInit(.public)
public struct RoutineEditorDataModel: Identifiable {
    @MemberwiseInit(.public)
    public struct Day: Identifiable {
        public var id: String
        public var picker: PickerDataModel
    }

    public let id = "routine"
    public var title: String
    public var name: TextFieldDataModel
    /// Where the week is described in plain words. Return reads it and fills the form.
    public var description: TextFieldDataModel
    /// What happened to the description; nil before one is read.
    public var descriptionFooter: String?
    public var daysHeader: String
    public var days: [Day]
    public var workHeader: String
    public var workStart: TimePickerDataModel
    public var workEnd: TimePickerDataModel
    /// Says what is wrong with the work hours; nil when they are fine.
    public var workFooter: String?
    public var sleepHeader: String
    public var wakeTime: TimePickerDataModel
    public var bedtime: TimePickerDataModel
    public var cancel: ButtonDataModel
    public var save: ButtonDataModel
}
