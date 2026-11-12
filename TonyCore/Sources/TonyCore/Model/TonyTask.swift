import Foundation

/// The "Task" of the solution document. Named `TonyTask` so that Swift's own `Task` keeps its meaning.
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
    public var cadence: Cadence?
    public var requirements: Requirements
    public var steps: [Step]
    public var mustHappenBy: Date?
    public var createdAt: Date

    public init(
        id: UUID,
        name: String,
        icon: String,
        kind: Kind,
        rank: Int,
        cadence: Cadence? = nil,
        requirements: Requirements = Requirements(),
        steps: [Step] = [],
        mustHappenBy: Date? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.kind = kind
        self.rank = rank
        self.cadence = cadence
        self.requirements = requirements
        self.steps = steps
        self.mustHappenBy = mustHappenBy
        self.createdAt = createdAt
    }
}
