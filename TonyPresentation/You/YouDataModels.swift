import Foundation
import MemberwiseInit
import TonyUIModels

/// The usual week in a few lines, with the button that opens its form.
@MemberwiseInit(.public)
public struct RoutineCardDataModel: Equatable {
    public var title: String
    public var edit: ButtonDataModel
    public var lines: [String]
}

/// Where calendar access stands, and the button that asks for it while it has not been asked.
@MemberwiseInit(.public)
public struct CalendarCardDataModel: Equatable {
    public var title: String
    public var text: String
    public var allow: ButtonDataModel?
}

/// The form for the name and the usual week.
@MemberwiseInit(.public)
public struct RoutineEditorDataModel: Identifiable, Equatable {
    @MemberwiseInit(.public)
    public struct Day: Identifiable, Equatable {
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
