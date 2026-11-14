import Foundation

// What a view needs to draw itself, and the functions it calls when the user acts on it.
// The values are already final: text is localised and formatted, and nothing is left for the view to decide.

public struct ButtonDataModel {
    public enum Role: Sendable {
        case normal
        case cancel
        case destructive
    }

    public var title: String
    public var systemImage: String?
    public var role: Role
    public var isEnabled: Bool
    public var accessibilityIdentifier: String?
    public var action: @MainActor () -> Void

    public init(
        title: String,
        systemImage: String? = nil,
        role: Role = .normal,
        isEnabled: Bool = true,
        accessibilityIdentifier: String? = nil,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }
}

public struct TextFieldDataModel {
    public var title: String
    public var text: String
    /// Shown while the field is empty; the title when nil.
    public var prompt: String?
    public var accessibilityIdentifier: String?
    public var onChange: @MainActor (String) -> Void

    public init(
        title: String,
        text: String,
        prompt: String? = nil,
        accessibilityIdentifier: String? = nil,
        onChange: @escaping @MainActor (String) -> Void
    ) {
        self.title = title
        self.text = text
        self.prompt = prompt
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onChange = onChange
    }
}

public struct ToggleDataModel: Identifiable {
    public var id: String
    public var title: String
    public var isOn: Bool
    public var onChange: @MainActor (Bool) -> Void

    public init(id: String, title: String, isOn: Bool, onChange: @escaping @MainActor (Bool) -> Void) {
        self.id = id
        self.title = title
        self.isOn = isOn
        self.onChange = onChange
    }
}

public struct StepperDataModel {
    public var title: String
    public var value: Int
    public var range: ClosedRange<Int>
    public var step: Int
    public var onChange: @MainActor (Int) -> Void

    public init(title: String, value: Int, range: ClosedRange<Int>, step: Int = 1, onChange: @escaping @MainActor (Int) -> Void) {
        self.title = title
        self.value = value
        self.range = range
        self.step = step
        self.onChange = onChange
    }
}

public struct PickerDataModel {
    public struct Option: Identifiable, Hashable, Sendable {
        public var id: String
        public var title: String

        public init(id: String, title: String) {
            self.id = id
            self.title = title
        }
    }

    public var title: String
    public var options: [Option]
    public var selectedID: String
    public var onSelect: @MainActor (String) -> Void

    public init(title: String, options: [Option], selectedID: String, onSelect: @escaping @MainActor (String) -> Void) {
        self.title = title
        self.options = options
        self.selectedID = selectedID
        self.onSelect = onSelect
    }
}

/// Picks a day, without a time.
public struct DatePickerDataModel {
    public var title: String
    public var date: Date
    public var onChange: @MainActor (Date) -> Void

    public init(title: String, date: Date, onChange: @escaping @MainActor (Date) -> Void) {
        self.title = title
        self.date = date
        self.onChange = onChange
    }
}

public struct AlertDataModel {
    public var title: String
    public var dismiss: ButtonDataModel

    public init(title: String, dismiss: ButtonDataModel) {
        self.title = title
        self.dismiss = dismiss
    }
}
