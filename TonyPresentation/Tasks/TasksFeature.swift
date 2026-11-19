import Foundation
import MemberwiseInit
import TonyCore
import TonyUIModels

/// The Tasks tab: the three lists, reordering, deleting, and the task form.
public enum TasksFeature: Feature {
    public struct State: Sendable, Equatable {
        public var tasks: [TonyTask] = []
        public var completions: [Completion] = []
        public var editor: TaskEditor.State?
        public var hasFailed = false

        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case appeared
        case loaded(tasks: [TonyTask], completions: [Completion])
        case failed
        case alertDismissed
        case addTapped(id: UUID, stepID: UUID, now: Date)
        case rowTapped(id: UUID, now: Date)
        case moved(kind: TonyTask.Kind, from: IndexSet, to: Int)
        case deleteTapped(id: UUID)
        case editor(TaskEditor.Action)
        case editorCancelled
        case editorSaved
        case editorDeleted
    }

    public enum Effect: Sendable, Equatable {
        case load
        case save(TonyTask)
        case delete(id: UUID)
        case reorder([UUID])
        case editor(TaskEditor.Effect)
    }

    @MemberwiseInit(.public)
    public struct Environment: Sendable {
        public var repository: any Repository
        public var catalog: (any TaskCatalog)?
        /// Reads the sentence a new task is typed in, with the rules; nil when there is no model.
        public var languageService: (any LanguageService)? = nil
        /// The language the catalogue answers in and sentences are read in.
        public var locale: Locale
        public var calendar: Calendar
        /// How long typing must pause before the catalogue is asked.
        public var suggestionDelay: Duration = .milliseconds(400)
    }

    static let kinds: [TonyTask.Kind] = [.recurring, .goal, .oneTime]

    // MARK: Reducer

    public static func reduce(_ state: inout State, _ action: Action) -> [Effect] {
        switch action {
        case .appeared:
            return [.load]
        case .loaded(let tasks, let completions):
            state.tasks = tasks
            state.completions = completions
        case .failed:
            state.hasFailed = true
        case .alertDismissed:
            state.hasFailed = false
        case .addTapped(let id, let stepID, let now):
            state.editor = .newTask(id: id, stepID: stepID, now: now)
        case .rowTapped(let id, let now):
            if let task = state.tasks.first(where: { $0.id == id }) {
                state.editor = TaskEditor.State(task: task, isNew: false, today: now)
            }
        case .moved(let kind, let source, let destination):
            let positions = state.tasks.indices.filter { state.tasks[$0].kind == kind }
            var reordered = positions.map { state.tasks[$0] }
            reordered.move(fromOffsets: source, toOffset: destination)
            for (position, task) in zip(positions, reordered) {
                state.tasks[position] = task
            }
            return [.reorder(reordered.map(\.id))]
        case .deleteTapped(let id):
            state.tasks.removeAll { $0.id == id }
            return [.delete(id: id)]
        case .editor(let editorAction):
            guard var editor = state.editor else { break }
            let effects = TaskEditor.reduce(&editor, editorAction)
            state.editor = editor
            return effects.map(Effect.editor)
        case .editorCancelled:
            state.editor = nil
        case .editorSaved:
            guard let editor = state.editor, editor.isValid else { break }
            let task = editor.editedTask
            if let index = state.tasks.firstIndex(where: { $0.id == task.id }) {
                state.tasks[index] = task
            } else {
                state.tasks.append(task)
            }
            state.editor = nil
            return [.save(task)]
        case .editorDeleted:
            guard let id = state.editor?.task.id else { break }
            state.tasks.removeAll { $0.id == id }
            state.editor = nil
            return [.delete(id: id)]
        }
        return []
    }

    // MARK: Effects

    public static func run(_ effect: Effect, in environment: Environment) async -> Action? {
        let repository = environment.repository
        switch effect {
        case .load:
            return await load(from: repository)
        case .save(let task):
            return await change(repository) { try await repository.save(task) }
        case .delete(let id):
            return await change(repository) { try await repository.deleteTask(id: id) }
        case .reorder(let orderedIDs):
            return await change(repository) { try await repository.reorderTasks(orderedIDs) }
        case .editor(.suggestSteps(let name)):
            let action = await TaskEditor.suggestSteps(
                forName: name,
                catalog: environment.catalog,
                locale: environment.locale,
                after: environment.suggestionDelay
            )
            return action.map { .editor($0) }
        case .editor(.read(let sentence, let now)):
            let action = await TaskEditor.read(
                sentence: sentence,
                now: now,
                calendar: environment.calendar,
                locale: environment.locale,
                service: environment.languageService
            )
            return .editor(action)
        }
    }

    public static func cancellationKey(for effect: Effect) -> String? {
        if case .editor = effect { "editor" } else { nil }
    }

    /// Applies a change, then reads everything back so the screen shows what the store holds.
    private static func change(_ repository: any Repository, _ change: () async throws -> Void) async -> Action {
        do {
            try await change()
        } catch {
            return .failed
        }
        return await load(from: repository)
    }

    private static func load(from repository: any Repository) async -> Action {
        do {
            return .loaded(tasks: try await repository.tasks(), completions: try await repository.completions())
        } catch {
            return .failed
        }
    }
}
