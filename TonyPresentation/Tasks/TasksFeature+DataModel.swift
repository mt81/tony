import Foundation
import TonyCore
import TonyUIModels

extension TasksFeature {
    @MainActor
    public static func dataModel(
        for state: State,
        context: PresentationContext,
        send: @escaping @MainActor (Action) -> Void
    ) -> TasksScreenDataModel {
        let locale = context.locale
        let addTask: any Executable<Void> = TonyUIModels.Action(id: "add_task") { _ in send(.addTapped(id: UUID(), stepID: UUID(), now: Date())) }

        return TasksScreenDataModel(
            title: localized("Tasks", locale),
            add: ButtonDataModel(title: localized("Add a task", locale), systemImage: "plus", accessibilityIdentifier: "addTask", action: addTask),
            sections: kinds.compactMap { kind in
                section(kind, state: state, context: context, send: send)
            },
            addTask: ButtonDataModel(title: localized("+ Add a task", locale), action: addTask),
            editor: state.editor.map { editor in
                TaskEditor.dataModel(
                    for: editor,
                    context: context,
                    edit: { send(.editor($0)) },
                    cancel: TonyUIModels.Action(id: "editorCancelled", parameters: Action.editorCancelled) { action, _ in send(action) },
                    save: TonyUIModels.Action(id: "editorSaved", parameters: Action.editorSaved) { action, _ in send(action) },
                    delete: TonyUIModels.Action(id: "editorDeleted", parameters: Action.editorDeleted) { action, _ in send(action) }
                )
            },
            dismissEditor: TonyUIModels.Action(id: "editorCancelled") { _ in send(.editorCancelled) },
            alert: state.hasFailed
                ? AlertDataModel(
                    title: localized("Your tasks could not be saved", locale),
                    dismiss: ButtonDataModel(
                        title: localized("OK", locale),
                        role: .cancel,
                        action: TonyUIModels.Action(id: "alertDismissed", parameters: Action.alertDismissed) { action, _ in send(action) }
                    )
                )
                : nil,
            onAppear: TonyUIModels.Action(id: "appeared") { _ in send(.appeared) }
        )
    }

    private static func section(
        _ kind: TonyTask.Kind,
        state: State,
        context: PresentationContext,
        send: @escaping @MainActor (Action) -> Void
    ) -> TaskSectionDataModel? {
        let tasks = state.tasks.filter { $0.kind == kind }
        guard !tasks.isEmpty else { return nil }
        let locale = context.locale
        let (title, hint): (String, String?) =
            switch kind {
            case .recurring: (localized("Recurring", locale), localized("Top matters most", locale))
            case .goal: (localized("Goals", locale), localized("Flexible days", locale))
            case .oneTime: (localized("One-time", locale), nil)
            }

        return TaskSectionDataModel(
            id: kind.rawValue,
            title: title,
            hint: hint,
            rows: tasks.map { task in
                let summary = TaskSummary(task: task, completions: state.completions, context: context)
                return TaskRowDataModel(
                    id: task.id,
                    icon: task.icon,
                    title: task.name,
                    subtitle: summary.subtitle,
                    status: ChipDataModel(title: summary.status, style: summary.isNeglected ? .warning : .neutral),
                    isNeglected: summary.isNeglected,
                    accessibilityIdentifier: "task-\(task.name)",
                    open: TonyUIModels.Action(id: "rowTapped", parameters: task.id) { id, _ in send(.rowTapped(id: id, now: Date())) },
                    delete: ButtonDataModel(
                        title: localized("Delete", locale),
                        role: .destructive,
                        action: TonyUIModels.Action(id: "deleteTapped", parameters: Action.deleteTapped(id: task.id)) { action, _ in send(action) }
                    )
                )
            },
            move: TonyUIModels.Action(id: "moved", parameters: kind) { kind, move in send(.moved(kind: kind, from: move.source, to: move.destination)) }
        )
    }
}
