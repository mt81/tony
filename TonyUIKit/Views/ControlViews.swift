import SwiftUI
import TonyUIModels

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
            .onSubmit { model.onSubmit?() }
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

public struct TimePickerView: View {
    private let model: TimePickerDataModel

    public init(_ model: TimePickerDataModel) {
        self.model = model
    }

    public var body: some View {
        DatePicker(model.title, selection: Binding(get: { model.time }, set: model.onChange), displayedComponents: .hourAndMinute)
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

#if DEBUG
#Preview("Controls") {
    Form {
        Section {
            TextFieldView(TextFieldDataModel(title: "Name", text: "", onChange: { _ in }))
            TextFieldView(TextFieldDataModel(title: "Name", text: "Water the plants", onChange: { _ in }))
            PickerView(
                PickerDataModel(
                    title: "Kind",
                    options: [.init(id: "recurring", title: "Recurring task"), .init(id: "goal", title: "Goal")],
                    selectedID: "recurring",
                    onSelect: { _ in }
                )
            )
            ToggleView(ToggleDataModel(id: "evening", title: "Evening", isOn: true, onChange: { _ in }))
            StepperView(StepperDataModel(title: "Every 5 days", value: 5, range: 1...365, onChange: { _ in }))
            DatePickerView(DatePickerDataModel(title: "Date", date: .now, onChange: { _ in }))
            TimePickerView(TimePickerDataModel(title: "Starts", time: .now, onChange: { _ in }))
        }
        Section {
            ButtonView(ButtonDataModel(title: "Add a step") {})
            ButtonView(ButtonDataModel(title: "Save", systemImage: "checkmark", isEnabled: false) {})
            ButtonView(ButtonDataModel(title: "Delete task", role: .destructive) {})
        }
    }
    .scrollContentBackground(.hidden)
    .tonyPreview(padding: 0)
}

#Preview("Alert") {
    TonyColor.canvas
        .alert(AlertDataModel(title: "Your tasks could not be saved", dismiss: ButtonDataModel(title: "OK", role: .cancel) {}))
        .tonyPreview(padding: 0)
}
#endif
