import Foundation

/// The on-device language model. It only words what the planner decided; it never decides the plan.
/// The app provides the real adapter; tests use fakes.
public protocol LanguageService: Sendable {
    /// Words the day described by the plan text, following the instructions. Throws when the model cannot answer.
    func briefing(instructions: String, plan: String) async throws -> String
}
