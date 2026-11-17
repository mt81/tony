import Foundation

/// Where tasks, completions, the routine and preferences are kept. The app provides the SwiftData store; tests use fakes.
public protocol Repository: Sendable {
    /// Every task, in rank order.
    func tasks() async throws -> [TonyTask]
    /// Updates the task with the same id and keeps its rank, or adds it at the end of the list.
    func save(_ task: TonyTask) async throws
    /// Deletes the task and its completions.
    func deleteTask(id: UUID) async throws
    /// Puts the given tasks in this order, within the ranks they already hold. Other tasks do not move.
    func reorderTasks(_ orderedIDs: [UUID]) async throws

    /// Every completion, oldest first.
    func completions() async throws -> [Completion]
    func save(_ completion: Completion) async throws

    func routine() async throws -> Routine?
    func save(_ routine: Routine) async throws

    func preferences() async throws -> [Preference]
    /// Replaces the preference with the same key, or adds it.
    func save(_ preference: Preference) async throws
}
