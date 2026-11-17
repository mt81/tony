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
    public var action: @MainActor () -> Void
}

@MemberwiseInit(.public)
public struct TextFieldDataModel {
    public var title: String
    public var text: String
    /// Shown while the field is empty; the title when nil.
    public var prompt: String? = nil
    public var accessibilityIdentifier: String? = nil
    public var onChange: @MainActor (String) -> Void
    /// Called when the user presses return; nil when return does nothing special.
    public var onSubmit: (@MainActor () -> Void)? = nil
}

@MemberwiseInit(.public)
public struct ToggleDataModel: Identifiable {
    public var id: String
    public var title: String
    public var isOn: Bool
    public var onChange: @MainActor (Bool) -> Void
}

@MemberwiseInit(.public)
public struct StepperDataModel {
    public var title: String
    public var value: Int
    public var range: ClosedRange<Int>
    public var step: Int = 1
    public var onChange: @MainActor (Int) -> Void
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
    public var onSelect: @MainActor (String) -> Void
}

/// Picks a day, without a time.
@MemberwiseInit(.public)
public struct DatePickerDataModel {
    public var title: String
    public var date: Date
    public var onChange: @MainActor (Date) -> Void
}

/// Picks a time of day. Only the hour and minute of the date count.
@MemberwiseInit(.public)
public struct TimePickerDataModel {
    public var title: String
    public var time: Date
    public var onChange: @MainActor (Date) -> Void
}

@MemberwiseInit(.public)
public struct AlertDataModel {
    public var title: String
    public var dismiss: ButtonDataModel
}
