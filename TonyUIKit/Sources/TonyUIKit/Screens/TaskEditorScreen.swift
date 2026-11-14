import SwiftUI
import TonyUIModels

/// The task form, drawn from its data model.
public struct TaskEditorScreen: View {
    private let model: TaskEditorDataModel

    public init(_ model: TaskEditorDataModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextFieldView(model.name)
                    TextFieldView(model.icon)
                    PickerView(model.kind)
                }
                if let cadence = model.cadence {
                    Section(cadence.header) {
                        PickerView(cadence.repeats)
                        if let count = cadence.count {
                            StepperView(count)
                        }
                        ForEach(cadence.weekdays) { ToggleView($0) }
                    }
                }
                Section(model.whenItFits.header) {
                    PickerView(model.whenItFits.location)
                    ForEach(model.whenItFits.toggles) { ToggleView($0) }
                }
                stepsSection
                Section(model.deadline.header) {
                    ToggleView(model.deadline.toggle)
                    if let date = model.deadline.date {
                        DatePickerView(date)
                    }
                }
                if let delete = model.delete {
                    ButtonView(delete)
                }
            }
            .scrollContentBackground(.hidden)
            .background(TonyColor.canvas)
            .navigationTitle(model.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ButtonView(model.cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    ButtonView(model.save)
                }
            }
        }
    }

    private var stepsSection: some View {
        let steps = model.steps
        return Section {
            ForEach(steps.steps) { step in
                VStack(alignment: .leading, spacing: TonySpacing.small) {
                    TextFieldView(step.name)
                    PickerView(step.mode)
                    StepperView(step.duration)
                    if let gap = step.gap {
                        StepperView(gap)
                    }
                }
            }
            .onMove(perform: steps.move)
            .onDelete(perform: steps.delete)
            .deleteDisabled(!steps.canDelete)
            ButtonView(steps.add)
        } header: {
            Text(steps.header)
        } footer: {
            if let footer = steps.footer {
                Text(footer)
            }
        }
    }
}
