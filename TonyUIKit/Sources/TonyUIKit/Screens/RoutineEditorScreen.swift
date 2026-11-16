import SwiftUI
import TonyUIModels

/// The form for the name and the usual week, drawn from its data model.
public struct RoutineEditorScreen: View {
    private let model: RoutineEditorDataModel

    public init(_ model: RoutineEditorDataModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextFieldView(model.name)
                }
                Section(model.daysHeader) {
                    ForEach(model.days) { day in
                        PickerView(day.picker)
                    }
                }
                Section {
                    TimePickerView(model.workStart)
                    TimePickerView(model.workEnd)
                } header: {
                    Text(model.workHeader)
                } footer: {
                    if let footer = model.workFooter {
                        Text(footer)
                    }
                }
                Section(model.sleepHeader) {
                    TimePickerView(model.wakeTime)
                    TimePickerView(model.bedtime)
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
}
