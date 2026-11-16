import Foundation

/// The on-device language model. It only words what the planner decided and reads what the user typed; it never decides the plan.
/// The app provides the real adapter; tests use fakes.
public protocol LanguageService: Sendable {
    /// Words the day described by the plan text, following the instructions. Throws when the model cannot answer.
    func briefing(instructions: String, plan: String) async throws -> String
    /// Reads one sentence as a task: its name and how it repeats. Throws when the model cannot answer.
    func taskDraft(instructions: String, sentence: String) async throws -> TaskDraft
    /// Reads a description of the user's week as a routine. Throws when the model cannot answer.
    func routine(instructions: String, description: String) async throws -> Routine
}
