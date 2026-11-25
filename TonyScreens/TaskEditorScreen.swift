import SwiftUI
import TonyPresentation
import TonyUIKit
import TonyUIModels

/// The task sheet, drawn from its data model: the composer for a new task, then the form.
public struct TaskEditorScreen: View {
    private let model: TaskEditorDataModel

    public init(_ model: TaskEditorDataModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let composer = model.composer {
                    TaskComposerView(composer)
                } else if let form = model.form {
                    TaskFormView(form)
                }
            }
            .navigationTitle(model.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ButtonView(model.cancel)
                        .tint(TonyColor.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    ButtonView(model.save)
                        .buttonStyle(.glassProminent)
                        .tint(TonyColor.accent)
                }
            }
        }
    }
}

/// The first step of a new task: Tony, and the box to describe the task in, above the keyboard.
struct TaskComposerView: View {
    private let model: TaskComposerDataModel

    init(_ model: TaskComposerDataModel) {
        self.model = model
    }

    var body: some View {
        ScrollView {
            VStack(spacing: TonySpacing.large) {
                TonyImage(color: TonyColor.muted)
                    .frame(width: TonySize.tonyHeader, height: TonySize.tonyHeader)
                Text(model.prompt)
                    .tonyText(.bodySmall)
                    .foregroundStyle(TonyColor.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, TonySpacing.small)
            .padding(.horizontal, TonySpacing.page)
        }
        .scrollDismissesKeyboard(.never)
        .safeAreaInset(edge: .bottom) {
            Composer(model.composer)
                .padding(.horizontal, TonySpacing.snug)
                .padding(.bottom, TonySpacing.snug)
                .background(TonyColor.surfaceRaised)
        }
        .background(TonyColor.surfaceRaised)
    }
}

/// The task as Tony read it, to review: every value opens a page to change it.
struct TaskFormView: View {
    private let model: TaskFormDataModel

    init(_ model: TaskFormDataModel) {
        self.model = model
    }

    var body: some View {
        List {
            Section {
                IconField(model.icon)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            .listSectionSpacing(TonySpacing.inset)
            Section {
                TextFieldView(model.name, axis: .vertical)
                    .tonyText(.title)
                    .foregroundStyle(TonyColor.ink)
                    .lineLimit(1...4)
                    .frame(minHeight: TonySize.touchTarget)
            }
            .glassRow()
            Section {
                repeatsRow
                if let countedFrom = model.countedFrom {
                    countedFromRow(countedFrom)
                }
                deadlineRow
            } header: {
                FormSectionHeader(model.scheduleHeader)
            }
            .glassRow()
            Section {
                choiceRow(model.location)
                checklistRow(model.timeOfDay)
                weatherRow
            } header: {
                FormSectionHeader(model.whenItFitsHeader)
            }
            .glassRow()
            subtasksSection
            if let delete = model.delete {
                Section {
                    ButtonView(delete)
                }
                .glassRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(TonyColor.surfaceRaised)
    }

    private var repeatsRow: some View {
        let repeats = model.repeats
        return NavigationLink {
            FormPage(title: repeats.row.title) {
                Section {
                    PickerView(repeats.choices)
                        .pickerStyle(.inline)
                        .labelsHidden()
                }
                .glassRow()
                if let timesPerWeek = repeats.timesPerWeek {
                    Section {
                        StepperView(timesPerWeek)
                    }
                    .glassRow()
                }
                if let custom = repeats.custom {
                    Section {
                        PickerView(custom.frequency)
                        if let count = custom.count {
                            StepperView(count)
                        }
                        ForEach(custom.weekdays) { CheckmarkRow($0) }
                    } header: {
                        FormSectionHeader(custom.header)
                    }
                    .glassRow()
                }
            }
        } label: {
            DetailRow(repeats.row)
        }
        .accessibilityIdentifier(ifPresent: repeats.row.accessibilityIdentifier)
    }

    private func countedFromRow(_ countedFrom: CountedFromDataModel) -> some View {
        NavigationLink {
            FormPage(title: countedFrom.row.title) {
                Section {
                    PickerView(countedFrom.choices)
                        .pickerStyle(.inline)
                        .labelsHidden()
                }
                .glassRow()
                if let start = countedFrom.start {
                    Section {
                        DatePickerView(start)
                    }
                    .glassRow()
                }
            }
        } label: {
            DetailRow(countedFrom.row)
        }
        .accessibilityIdentifier(ifPresent: countedFrom.row.accessibilityIdentifier)
    }

    private var deadlineRow: some View {
        let deadline = model.deadline
        return NavigationLink {
            FormPage(title: deadline.row.title) {
                Section {
                    ToggleView(deadline.toggle)
                    if let date = deadline.date {
                        DatePickerView(date)
                    }
                }
                .glassRow()
            }
        } label: {
            DetailRow(deadline.row)
        }
        .accessibilityIdentifier(ifPresent: deadline.row.accessibilityIdentifier)
    }

    private func choiceRow(_ choice: ChoiceDataModel) -> some View {
        NavigationLink {
            FormPage(title: choice.row.title) {
                Section {
                    PickerView(choice.choices)
                        .pickerStyle(.inline)
                        .labelsHidden()
                }
                .glassRow()
            }
        } label: {
            DetailRow(choice.row)
        }
        .accessibilityIdentifier(ifPresent: choice.row.accessibilityIdentifier)
    }

    private func checklistRow(_ checklist: ChecklistDataModel) -> some View {
        NavigationLink {
            FormPage(title: checklist.row.title) {
                Section {
                    ForEach(checklist.items) { CheckmarkRow($0) }
                }
                .glassRow()
            }
        } label: {
            DetailRow(checklist.row)
        }
        .accessibilityIdentifier(ifPresent: checklist.row.accessibilityIdentifier)
    }

    private var weatherRow: some View {
        let weather = model.weather
        return NavigationLink {
            FormPage(title: weather.row.title) {
                Section {
                    CheckmarkRow(weather.any)
                }
                .glassRow()
                Section {
                    ToggleSegments(weather.conditions)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    FormSectionHeader(weather.header)
                } footer: {
                    Text(weather.footer)
                        .tonyText(.bodySmall)
                        .foregroundStyle(TonyColor.muted)
                }
            }
        } label: {
            DetailRow(weather.row)
        }
        .accessibilityIdentifier(ifPresent: weather.row.accessibilityIdentifier)
    }

    private var subtasksSection: some View {
        let subtasks = model.subtasks
        return Section {
            ForEach(subtasks.subtasks) { subtask in
                HStack(spacing: TonySpacing.medium) {
                    TextFieldView(subtask.name)
                        .tonyText(.bodyLarge)
                        .foregroundStyle(TonyColor.ink)
                    PickerView(subtask.duration)
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .fixedSize()
                }
                .frame(minHeight: TonySize.touchTarget)
            }
            .onMove { subtasks.move.execute(Move(source: $0, destination: $1)) }
            .onDelete { subtasks.delete.execute($0) }
            .deleteDisabled(!subtasks.canDelete)
            ButtonView(subtasks.add)
        } header: {
            FormSectionHeader(subtasks.header)
        }
        .glassRow()
    }
}

/// A page the form opens to change one value, on the same background as the form.
private struct FormPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        List {
            content
        }
        .scrollContentBackground(.hidden)
        .background(TonyColor.surfaceRaised)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("New task, typing") {
    TaskEditorScreen(PreviewSamples.taskComposer)
        .tonyPreview(padding: 0)
}

#Preview("New task, understood") {
    TaskEditorScreen(PreviewSamples.taskEditor)
        .tonyPreview(padding: 0)
}

#Preview("New task, largest text") {
    TaskEditorScreen(PreviewSamples.taskEditor)
        .tonyPreview(padding: 0)
        .dynamicTypeSize(.accessibility5)
}
#endif
