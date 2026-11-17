import Foundation
import MemberwiseInit

/// One part of a multi-step task. Steps run in the order of `TonyTask.steps`.
@MemberwiseInit(.public)
public struct Step: Codable, Sendable, Hashable, Identifiable {
    public enum Mode: String, Codable, Sendable, Hashable, CaseIterable {
        case active
        case background
    }

    public var id: UUID
    public var name: String
    public var mode: Mode
    public var duration: TimeInterval
    public var minimumGapToNextStep: TimeInterval = 0
    public var requirements: Requirements = Requirements()
}
