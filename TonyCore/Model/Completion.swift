import Foundation

/// What happened to a task, or to one of its steps. A nil `stepID` is about the task as a whole.
public struct Completion: Codable, Sendable, Hashable, Identifiable {
    public enum Outcome: String, Codable, Sendable, Hashable, CaseIterable {
        case done
        case later
        case notToday
        case skipped
    }

    public var id: UUID
    public var taskID: UUID
    public var stepID: UUID?
    public var date: Date
    public var outcome: Outcome

    public init(id: UUID, taskID: UUID, stepID: UUID? = nil, date: Date, outcome: Outcome) {
        self.id = id
        self.taskID = taskID
        self.stepID = stepID
        self.date = date
        self.outcome = outcome
    }
}
