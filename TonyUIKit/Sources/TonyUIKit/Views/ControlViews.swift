import SwiftUI

// System controls drawn from their data models. A change the user makes is reported through the data model;
// the control shows it once a new data model comes back.

public struct ButtonView: View {
    private let model: ButtonDataModel

    public init(_ model: ButtonDataModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            if let systemImage = model.systemImage {
                Button(model.title, systemImage: systemImage, role: model.role.buttonRole, action: model.action)
            } else {
                Button(model.title, role: model.role.buttonRole, action: model.action)
            }
        }
        .disabled(!model.isEnabled)
        .accessibilityIdentifier(ifPresent: model.accessibilityIdentifier)
    }
}

public struct TextFieldView: View {
    private let model: TextFieldDataModel

    public init(_ model: TextFieldDataModel) {
        self.model = model
    }

    public var body: some View {
        TextField(model.title, text: Binding(get: { model.text }, set: model.onChange), prompt: Text(model.prompt ?? model.title))
            .accessibilityIdentifier(ifPresent: model.accessibilityIdentifier)
    }
}

public struct ToggleView: View {
    private let model: ToggleDataModel

    public init(_ model: ToggleDataModel) {
        self.model = model
    }

    public var body: some View {
        Toggle(model.title, isOn: Binding(get: { model.isOn }, set: model.onChange))
    }
}

public struct StepperView: View {
    private let model: StepperDataModel

    public init(_ model: StepperDataModel) {
        self.model = model
    }

    public var body: some View {
        Stepper(model.title, value: Binding(get: { model.value }, set: model.onChange), in: model.range, step: model.step)
    }
}

public struct PickerView: View {
    private let model: PickerDataModel

    public init(_ model: PickerDataModel) {
        self.model = model
    }

    public var body: some View {
        Picker(model.title, selection: Binding(get: { model.selectedID }, set: model.onSelect)) {
            ForEach(model.options) { option in
                Text(option.title).tag(option.id)
            }
        }
    }
}

public struct DatePickerView: View {
    private let model: DatePickerDataModel

    public init(_ model: DatePickerDataModel) {
        self.model = model
    }

    public var body: some View {
        DatePicker(model.title, selection: Binding(get: { model.date }, set: model.onChange), displayedComponents: .date)
    }
}

extension View {
    /// Shows the alert while the data model is there.
    public func alert(_ model: AlertDataModel?) -> some View {
        alert(
            model?.title ?? "",
            isPresented: Binding(get: { model != nil }, set: { isPresented in
                if !isPresented, let model {
                    model.dismiss.action()
                }
            })
        ) {
            if let model {
                Button(model.dismiss.title, role: .cancel) {}
            }
        }
    }
}

extension ButtonDataModel.Role {
    var buttonRole: ButtonRole? {
        switch self {
        case .normal: nil
        case .cancel: .cancel
        case .destructive: .destructive
        }
    }
}

extension View {
    /// Sets the identifier only when there is one, so views without one keep the system's.
    @ViewBuilder
    public func accessibilityIdentifier(ifPresent identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
