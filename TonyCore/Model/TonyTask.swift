import Foundation
import MemberwiseInit

/// The "Task" of the solution document. Named `TonyTask` so that Swift's own `Task` keeps its meaning.
@MemberwiseInit(.public)
public struct TonyTask: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable, Hashable, CaseIterable {
        case recurring
        case oneTime
        case goal
    }

    public var id: UUID
    public var name: String
    public var icon: String
    public var kind: Kind
    public var rank: Int
    public var cadence: Cadence? = nil
    public var requirements: Requirements = Requirements()
    public var steps: [Step] = []
    public var mustHappenBy: Date? = nil
    public var createdAt: Date
}
