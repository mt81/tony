import Foundation
import MemberwiseInit

/// What happened to a task, or to one of its steps. A nil `stepID` is about the task as a whole.
@MemberwiseInit(.public)
public struct Completion: Codable, Sendable, Hashable, Identifiable {
    public enum Outcome: String, Codable, Sendable, Hashable, CaseIterable {
        case done
        case later
        case notToday
        case skipped
    }

    public var id: UUID
    public var taskID: UUID
    public var stepID: UUID? = nil
    public var date: Date
    public var outcome: Outcome
}
