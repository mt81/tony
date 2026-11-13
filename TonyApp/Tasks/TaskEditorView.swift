import SwiftUI
import TonyCore
import TonyDesign

struct TaskEditorView: View {
    @State private var task: TonyTask
    @State private var cadenceKind: CadenceKind
    @State private var everyDays: Int
    @State private var weekdays: Set<Locale.Weekday>
    @State private var timesPerWeek: Int
    @State private var hasDeadline: Bool
    @State private var deadline: Date

    private let isNew: Bool
    private let onSave: (TonyTask) -> Void
    private let onDelete: (TonyTask) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    private enum CadenceKind: Hashable, CaseIterable {
        case afterCompletion
        case weekdays
        case timesPerWeek
    }

    init(task: TonyTask, isNew: Bool, onSave: @escaping (TonyTask) -> Void, onDelete: @escaping (TonyTask) -> Void) {
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
        _task = State(initialValue: task)
        _hasDeadline = State(initialValue: task.mustHappenBy != nil)
        _deadline = State(initialValue: task.mustHappenBy ?? .now)

        var kind = CadenceKind.afterCompletion
        var days = 7
        var chosenWeekdays: Set<Locale.Weekday> = []
        var times = 3
        switch task.cadence {
        case .afterCompletion(let value): days = value
        case .weekdays(let value): (kind, chosenWeekdays) = (.weekdays, value)
        case .timesPerWeek(let value): (kind, times) = (.timesPerWeek, value)
        case nil: break
        }
        _cadenceKind = State(initialValue: kind)
        _everyDays = State(initialValue: days)
        _weekdays = State(initialValue: chosenWeekdays)
        _timesPerWeek = State(initialValue: times)
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                if task.kind != .oneTime {
                    cadenceSection
                }
                whenItFitsSection
                stepsSection
                deadlineSection
                if !isNew {
                    Button("Delete task", role: .destructive) {
                        onDelete(task)
                        dismiss()
                    }
                    .accessibilityIdentifier("deleteTask")
                }
            }
            .scrollContentBackground(.hidden)
            .background(TonyColor.canvas)
            .navigationTitle(isNew ? Text("New task") : Text("Edit task"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        onSave(editedTask)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .accessibilityIdentifier("saveTask")
                }
            }
        }
    }

    private var nameSection: some View {
        Section {
            TextField("Name", text: $task.name)
                .accessibilityIdentifier("taskName")
            TextField("Icon", text: $task.icon)
            Picker("Kind", selection: $task.kind) {
                Text("Recurring task").tag(TonyTask.Kind.recurring)
                Text("Goal").tag(TonyTask.Kind.goal)
                Text("One-time task").tag(TonyTask.Kind.oneTime)
            }
        }
    }

    private var cadenceSection: some View {
        Section("Cadence") {
            Picker("Repeats", selection: $cadenceKind) {
                Text("After it was last done").tag(CadenceKind.afterCompletion)
                Text("On fixed days").tag(CadenceKind.weekdays)
                Text("A number of times a week").tag(CadenceKind.timesPerWeek)
            }
            switch cadenceKind {
            case .afterCompletion:
                Stepper("Every \(everyDays) days", value: $everyDays, in: 1...365)
            case .weekdays:
                ForEach(calendar.orderedWeekdays(locale: locale), id: \.weekday) { day in
                    Toggle(day.name.capitalized(with: locale), isOn: membership(of: day.weekday, in: $weekdays))
                }
            case .timesPerWeek:
                Stepper("\(timesPerWeek) times a week", value: $timesPerWeek, in: 1...7)
            }
        }
    }

    private var whenItFitsSection: some View {
        Section("When it fits") {
            Picker("Where", selection: $task.requirements.location) {
                Text("Anywhere").tag(Location?.none)
                Text("At home").tag(Location?.some(.home))
                Text("At the office").tag(Location?.some(.office))
            }
            Toggle("Morning", isOn: membership(of: .morning, in: $task.requirements.windows))
            Toggle("Work hours", isOn: membership(of: .workday, in: $task.requirements.windows))
            Toggle("Evening", isOn: membership(of: .evening, in: $task.requirements.windows))
            Toggle("Not in the rain", isOn: membership(of: .rain, in: $task.requirements.avoidedWeather))
            Toggle("Costs money", isOn: $task.requirements.costsMoney)
        }
    }

    private var stepsSection: some View {
        Section("Steps") {
            ForEach($task.steps) { $step in
                VStack(alignment: .leading, spacing: TonySpacing.small) {
                    TextField("Step name", text: $step.name, prompt: Text(trimmedName.isEmpty ? String(localized: "Step name") : trimmedName))
                    Picker("How", selection: $step.mode) {
                        Text("I do it").tag(Step.Mode.active)
                        Text("It runs on its own").tag(Step.Mode.background)
                    }
                    Stepper("Lasts \(minutes(step.duration)) min", value: minutesBinding($step.duration), in: 5...480, step: 5)
                    if step.id != task.steps.last?.id {
                        Stepper("Then wait \(minutes(step.minimumGapToNextStep)) min", value: minutesBinding($step.minimumGapToNextStep), in: 0...480, step: 5)
                    }
                }
            }
            .onMove { task.steps.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { task.steps.remove(atOffsets: $0) }
            .deleteDisabled(task.steps.count == 1)

            Button("Add a step") {
                task.steps.append(Step(id: UUID(), name: "", mode: .active, duration: 30 * 60))
            }
        }
    }

    private var deadlineSection: some View {
        Section("Deadline") {
            Toggle("Must happen by a date", isOn: $hasDeadline)
            if hasDeadline {
                DatePicker("Date", selection: $deadline, displayedComponents: .date)
            }
        }
    }

    private var isValid: Bool {
        let needsWeekdays = task.kind != .oneTime && cadenceKind == .weekdays
        return !trimmedName.isEmpty && !(needsWeekdays && weekdays.isEmpty)
    }

    private var trimmedName: String {
        task.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The task as the form describes it: cadence and deadline folded in, unnamed steps named after the task.
    private var editedTask: TonyTask {
        var edited = task
        edited.name = trimmedName
        edited.mustHappenBy = hasDeadline ? deadline : nil
        edited.cadence =
            if task.kind == .oneTime {
                nil
            } else {
                switch cadenceKind {
                case .afterCompletion: .afterCompletion(days: everyDays)
                case .weekdays: .weekdays(weekdays)
                case .timesPerWeek: .timesPerWeek(timesPerWeek)
                }
            }
        for index in edited.steps.indices where edited.steps[index].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            edited.steps[index].name = trimmedName
        }
        return edited
    }

    private func minutes(_ duration: TimeInterval) -> Int {
        Int(duration / 60)
    }

    private func minutesBinding(_ duration: Binding<TimeInterval>) -> Binding<Int> {
        Binding(get: { Int(duration.wrappedValue / 60) }, set: { duration.wrappedValue = TimeInterval($0 * 60) })
    }

    private func membership<Element: Hashable>(of element: Element, in set: Binding<Set<Element>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(element) },
            set: { isOn in
                if isOn {
                    set.wrappedValue.insert(element)
                } else {
                    set.wrappedValue.remove(element)
                }
            }
        )
    }
}
