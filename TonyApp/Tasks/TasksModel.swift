import Foundation
import Observation
import TonyCore

/// What the Tasks tab shows and the actions it sends to the store.
@MainActor
@Observable
final class TasksModel {
    private(set) var tasks: [TonyTask] = []
    private(set) var completions: [Completion] = []
    var hasFailed = false

    private let repository: any Repository

    init(repository: any Repository) {
        self.repository = repository
    }

    func tasks(of kind: TonyTask.Kind) -> [TonyTask] {
        tasks.filter { $0.kind == kind }
    }

    func load() async {
        await run {}
    }

    func save(_ task: TonyTask) async {
        await run { try await self.repository.save(task) }
    }

    func delete(_ task: TonyTask) async {
        await run { try await self.repository.deleteTask(id: task.id) }
    }

    func move(kind: TonyTask.Kind, from source: IndexSet, to destination: Int) async {
        var reordered = tasks(of: kind)
        reordered.move(fromOffsets: source, toOffset: destination)
        let orderedIDs = reordered.map(\.id)
        await run { try await self.repository.reorderTasks(orderedIDs) }
    }

    /// Applies a change, then reads everything back so the screen shows what the store holds.
    private func run(_ change: () async throws -> Void) async {
        do {
            try await change()
            tasks = try await repository.tasks()
            completions = try await repository.completions()
        } catch {
            hasFailed = true
        }
    }
}
