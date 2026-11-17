import Foundation
import TonyUIModels

/// The You tab: who the user is, their routine and what Tony may read. The rest of the tab comes with C25.
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

    public init(
        initial: String?,
        name: String,
        routine: RoutineCardDataModel,
        calendar: CalendarCardDataModel,
        editor: RoutineEditorDataModel?,
        dismissEditor: @escaping @MainActor () -> Void,
        alert: AlertDataModel?,
        onAppear: @escaping @MainActor () -> Void
    ) {
        self.initial = initial
        self.name = name
        self.routine = routine
        self.calendar = calendar
        self.editor = editor
        self.dismissEditor = dismissEditor
        self.alert = alert
        self.onAppear = onAppear
    }
}

/// The usual week in a few lines, with the button that opens its form.
public struct RoutineCardDataModel {
    public var title: String
    public var edit: ButtonDataModel
    public var lines: [String]

    public init(title: String, edit: ButtonDataModel, lines: [String]) {
        self.title = title
        self.edit = edit
        self.lines = lines
    }
}

/// Where calendar access stands, and the button that asks for it while it has not been asked.
public struct CalendarCardDataModel {
    public var title: String
    public var text: String
    public var allow: ButtonDataModel?

    public init(title: String, text: String, allow: ButtonDataModel?) {
        self.title = title
        self.text = text
        self.allow = allow
    }
}

/// The form for the name and the usual week.
public struct RoutineEditorDataModel: Identifiable {
    public struct Day: Identifiable {
        public var id: String
        public var picker: PickerDataModel

        public init(id: String, picker: PickerDataModel) {
            self.id = id
            self.picker = picker
        }
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

    public init(
        title: String,
        name: TextFieldDataModel,
        description: TextFieldDataModel,
        descriptionFooter: String?,
        daysHeader: String,
        days: [Day],
        workHeader: String,
        workStart: TimePickerDataModel,
        workEnd: TimePickerDataModel,
        workFooter: String?,
        sleepHeader: String,
        wakeTime: TimePickerDataModel,
        bedtime: TimePickerDataModel,
        cancel: ButtonDataModel,
        save: ButtonDataModel
    ) {
        self.title = title
        self.name = name
        self.description = description
        self.descriptionFooter = descriptionFooter
        self.daysHeader = daysHeader
        self.days = days
        self.workHeader = workHeader
        self.workStart = workStart
        self.workEnd = workEnd
        self.workFooter = workFooter
        self.sleepHeader = sleepHeader
        self.wakeTime = wakeTime
        self.bedtime = bedtime
        self.cancel = cancel
        self.save = save
    }
}
