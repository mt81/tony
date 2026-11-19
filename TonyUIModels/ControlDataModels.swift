import Foundation
import MemberwiseInit

// What a view needs to draw itself, and the functions it calls when the user acts on it.
// The values are already final: text is localised and formatted, and nothing is left for the view to decide.

@MemberwiseInit(.public)
public struct ButtonDataModel {
    public enum Role: Sendable {
        case normal
        case cancel
        case destructive
    }

    public var title: String
    public var systemImage: String? = nil
    public var role: Role = .normal
    public var isEnabled: Bool = true
    public var accessibilityIdentifier: String? = nil
    public var action: any Executable<Void>
}

extension ButtonDataModel: Equatable {
    public static func == (lhs: ButtonDataModel, rhs: ButtonDataModel) -> Bool {
        lhs.title == rhs.title
            && lhs.systemImage == rhs.systemImage
            && lhs.role == rhs.role
            && lhs.isEnabled == rhs.isEnabled
            && lhs.accessibilityIdentifier == rhs.accessibilityIdentifier
            && lhs.action.isEqual(to: rhs.action)
    }
}

@MemberwiseInit(.public)
public struct TextFieldDataModel {
    public var title: String
    public var text: String
    /// Shown while the field is empty; the title when nil.
    public var prompt: String? = nil
    public var accessibilityIdentifier: String? = nil
    public var onChange: any Executable<String>
    /// Run when the user presses return; nil when return does nothing special.
    public var onSubmit: (any Executable<Void>)? = nil
}

extension TextFieldDataModel: Equatable {
    public static func == (lhs: TextFieldDataModel, rhs: TextFieldDataModel) -> Bool {
        lhs.title == rhs.title
            && lhs.text == rhs.text
            && lhs.prompt == rhs.prompt
            && lhs.accessibilityIdentifier == rhs.accessibilityIdentifier
            && lhs.onChange.isEqual(to: rhs.onChange)
            && isEqual(lhs.onSubmit, rhs.onSubmit)
    }
}

@MemberwiseInit(.public)
public struct ToggleDataModel: Identifiable {
    public var id: String
    public var title: String
    public var isOn: Bool
    public var onChange: any Executable<Bool>
}

extension ToggleDataModel: Equatable {
    public static func == (lhs: ToggleDataModel, rhs: ToggleDataModel) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.isOn == rhs.isOn && lhs.onChange.isEqual(to: rhs.onChange)
    }
}

@MemberwiseInit(.public)
public struct StepperDataModel {
    public var title: String
    public var value: Int
    public var range: ClosedRange<Int>
    public var step: Int = 1
    public var onChange: any Executable<Int>
}

extension StepperDataModel: Equatable {
    public static func == (lhs: StepperDataModel, rhs: StepperDataModel) -> Bool {
        lhs.title == rhs.title
            && lhs.value == rhs.value
            && lhs.range == rhs.range
            && lhs.step == rhs.step
            && lhs.onChange.isEqual(to: rhs.onChange)
    }
}

@MemberwiseInit(.public)
public struct PickerDataModel {
    @MemberwiseInit(.public)
    public struct Option: Identifiable, Hashable, Sendable {
        public var id: String
        public var title: String
    }

    public var title: String
    public var options: [Option]
    public var selectedID: String
    public var onSelect: any Executable<String>
}

extension PickerDataModel: Equatable {
    public static func == (lhs: PickerDataModel, rhs: PickerDataModel) -> Bool {
        lhs.title == rhs.title && lhs.options == rhs.options && lhs.selectedID == rhs.selectedID && lhs.onSelect.isEqual(to: rhs.onSelect)
    }
}

/// Picks a day, without a time.
@MemberwiseInit(.public)
public struct DatePickerDataModel {
    public var title: String
    public var date: Date
    public var onChange: any Executable<Date>
}

extension DatePickerDataModel: Equatable {
    public static func == (lhs: DatePickerDataModel, rhs: DatePickerDataModel) -> Bool {
        lhs.title == rhs.title && lhs.date == rhs.date && lhs.onChange.isEqual(to: rhs.onChange)
    }
}

/// Picks a time of day. Only the hour and minute of the date count.
@MemberwiseInit(.public)
public struct TimePickerDataModel {
    public var title: String
    public var time: Date
    public var onChange: any Executable<Date>
}

extension TimePickerDataModel: Equatable {
    public static func == (lhs: TimePickerDataModel, rhs: TimePickerDataModel) -> Bool {
        lhs.title == rhs.title && lhs.time == rhs.time && lhs.onChange.isEqual(to: rhs.onChange)
    }
}

@MemberwiseInit(.public)
public struct AlertDataModel: Equatable {
    public var title: String
    public var dismiss: ButtonDataModel
}

/// Two optional executables are equal when both are missing, or both are there and equal.
private func isEqual(_ lhs: (any Executable)?, _ rhs: (any Executable)?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil): true
    case let (lhs?, rhs?): lhs.isEqual(to: rhs)
    default: false
    }
}

/// Rows of a list the user dragged: where they were, and where they go.
@MemberwiseInit(.public)
public struct Move: Equatable, Sendable {
    public var source: IndexSet
    public var destination: Int
}
