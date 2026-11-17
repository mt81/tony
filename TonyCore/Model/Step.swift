import Foundation

/// One part of a multi-step task. Steps run in the order of `TonyTask.steps`.
public struct Step: Codable, Sendable, Hashable, Identifiable {
    public enum Mode: String, Codable, Sendable, Hashable, CaseIterable {
        case active
        case background
    }

    public var id: UUID
    public var name: String
    public var mode: Mode
    public var duration: TimeInterval
    public var minimumGapToNextStep: TimeInterval
    public var requirements: Requirements

    public init(
        id: UUID,
        name: String,
        mode: Mode,
        duration: TimeInterval,
        minimumGapToNextStep: TimeInterval = 0,
        requirements: Requirements = Requirements()
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.duration = duration
        self.minimumGapToNextStep = minimumGapToNextStep
        self.requirements = requirements
    }
}
