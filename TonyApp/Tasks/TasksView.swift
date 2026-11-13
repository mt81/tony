import SwiftUI
import TonyCore
import TonyDesign

struct TasksView: View {
    @State private var model: TasksModel
    @State private var edited: EditedTask?
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    init(repository: any Repository) {
        _model = State(initialValue: TasksModel(repository: repository))
    }

    var body: some View {
        List {
            header
            section(.recurring, title: "Recurring", hint: "Top matters most")
            section(.goal, title: "Goals", hint: "Flexible days")
            section(.oneTime, title: "One-time", hint: nil)
            addTaskRow
        }
        .listStyle(.plain)
        .listRowSpacing(TonySpacing.small)
        .scrollContentBackground(.hidden)
        .background {
            LinearGradient(
                stops: [.init(color: TonyColor.glow, location: 0), .init(color: TonyColor.canvas, location: 0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .task { await model.load() }
        .sheet(item: $edited) { edited in
            TaskEditorView(
                task: edited.task,
                isNew: edited.isNew,
                onSave: { task in Task { await model.save(task) } },
                onDelete: { task in Task { await model.delete(task) } }
            )
        }
        .alert("Your tasks could not be saved", isPresented: $model.hasFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: TonySpacing.medium) {
            Text("Tasks")
                .tonyText(.display)
                .foregroundStyle(TonyColor.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: addTask) {
                Image(systemName: "plus")
                    .tonyText(.heading)
                    .foregroundStyle(TonyColor.onAccent)
                    .padding(TonySpacing.snug)
                    .frame(minWidth: TonySize.touchTarget, minHeight: TonySize.touchTarget)
                    .background(TonyColor.accent, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a task")
            .accessibilityIdentifier("addTask")
        }
        .plainRow()
    }

    @ViewBuilder
    private func section(_ kind: TonyTask.Kind, title: LocalizedStringKey, hint: LocalizedStringKey?) -> some View {
        let tasks = model.tasks(of: kind)
        if !tasks.isEmpty {
            Section {
                ForEach(tasks) { task in
                    row(for: task)
                }
                .onMove { source, destination in
                    Task { await model.move(kind: kind, from: source, to: destination) }
                }
            } header: {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: TonySpacing.small) {
                        sectionTitle(title)
                        Spacer()
                        sectionHint(hint)
                    }
                    VStack(alignment: .leading, spacing: TonySpacing.xSmall) {
                        sectionTitle(title)
                        sectionHint(hint)
                    }
                }
                .textCase(nil)
                .padding(.top, TonySpacing.large)
                .listRowInsets(EdgeInsets(top: 0, leading: TonySpacing.page, bottom: TonySpacing.small, trailing: TonySpacing.page))
            }
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .tonyText(.heading)
            .foregroundStyle(TonyColor.ink)
            .fixedSize()
    }

    @ViewBuilder
    private func sectionHint(_ hint: LocalizedStringKey?) -> some View {
        if let hint {
            Text(hint)
                .tonyText(.caption)
                .foregroundStyle(TonyColor.muted)
        }
    }

    private func row(for task: TonyTask) -> some View {
        let summary = TaskSummary(task: task, completions: model.completions, now: .now, calendar: calendar, locale: locale)
        return Button {
            edited = EditedTask(task: task, isNew: false)
        } label: {
            TaskRow(icon: task.icon, title: task.name, subtitle: summary.subtitle, status: summary.status, isNeglected: summary.isNeglected)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("task-\(task.name)")
        .swipeActions {
            Button("Delete", role: .destructive) {
                Task { await model.delete(task) }
            }
        }
        .plainRow()
    }

    private var addTaskRow: some View {
        Button(action: addTask) {
            Text("+ Add a task")
                .tonyText(.label)
                .foregroundStyle(TonyColor.muted)
                .frame(maxWidth: .infinity, minHeight: TonySize.touchTarget)
                .padding(.vertical, TonySpacing.xSmall)
                .overlay {
                    RoundedRectangle(cornerRadius: TonyRadius.row)
                        .strokeBorder(TonyColor.line, style: StrokeStyle(lineWidth: TonySize.border, dash: [TonySpacing.tight]))
                }
        }
        .buttonStyle(.plain)
        .padding(.top, TonySpacing.small)
        .plainRow()
    }

    private func addTask() {
        edited = EditedTask(task: .new(), isNew: true)
    }
}

private struct EditedTask: Identifiable {
    let task: TonyTask
    let isNew: Bool

    var id: UUID { task.id }
}

extension View {
    /// A list row that shows only its content: no separator, no system background, page margins.
    fileprivate func plainRow() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: TonySpacing.page, bottom: 0, trailing: TonySpacing.page))
    }
}

extension TonyTask {
    /// A blank recurring task with the one step every task has.
    static func new() -> TonyTask {
        TonyTask(
            id: UUID(),
            name: "",
            icon: "✅",
            kind: .recurring,
            rank: 0,
            cadence: .afterCompletion(days: 7),
            steps: [Step(id: UUID(), name: "", mode: .active, duration: 30 * 60)],
            createdAt: .now
        )
    }
}
