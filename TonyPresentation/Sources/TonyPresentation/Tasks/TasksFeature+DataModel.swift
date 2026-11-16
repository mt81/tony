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
        let addTask: @MainActor () -> Void = { send(.addTapped(id: UUID(), stepID: UUID(), now: Date())) }

        return TasksScreenDataModel(
            title: localized("Tasks", locale),
            add: ButtonDataModel(title: localized("Add a task", locale), systemImage: "plus", accessibilityIdentifier: "addTask", action: addTask),
            quickAdd: TextFieldDataModel(
                title: localized("Tell Tony what to add", locale),
                text: state.quickAdd,
                prompt: localized("Tell Tony… “water the plants every 5 days”", locale),
                accessibilityIdentifier: "quickAdd",
                onChange: { send(.quickAddChanged($0)) },
                onSubmit: { send(.quickAddSubmitted(id: UUID(), stepID: UUID(), now: Date())) }
            ),
            sections: kinds.compactMap { kind in
                section(kind, state: state, context: context, send: send)
            },
            addTask: ButtonDataModel(title: localized("+ Add a task", locale), action: addTask),
            editor: state.editor.map { editor in
                TaskEditor.dataModel(
                    for: editor,
                    context: context,
                    edit: { send(.editor($0)) },
                    cancel: { send(.editorCancelled) },
                    save: { send(.editorSaved) },
                    delete: { send(.editorDeleted) }
                )
            },
            dismissEditor: { send(.editorCancelled) },
            alert: state.hasFailed
                ? AlertDataModel(
                    title: localized("Your tasks could not be saved", locale),
                    dismiss: ButtonDataModel(title: localized("OK", locale), role: .cancel) { send(.alertDismissed) }
                )
                : nil,
            onAppear: { send(.appeared) }
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
                    open: { send(.rowTapped(id: task.id, now: Date())) },
                    delete: ButtonDataModel(title: localized("Delete", locale), role: .destructive) { send(.deleteTapped(id: task.id)) }
                )
            },
            move: { source, destination in send(.moved(kind: kind, from: source, to: destination)) }
        )
    }
}
