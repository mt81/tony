import Foundation

/// The shared catalogue of how common tasks break down into steps (D14). Every device gets the same answer for the same task.
public protocol TaskCatalog: Sendable {
    /// The steps of a task with this name, named in the locale's language, or nil when the catalogue does not know the task.
    func steps(forTaskNamed name: String, locale: Locale) async throws -> [StepTemplate]?
}

public struct StepTemplate: Codable, Sendable, Hashable {
    public var name: String
    public var mode: Step.Mode
    public var duration: TimeInterval
    public var minimumGapToNextStep: TimeInterval

    public init(name: String, mode: Step.Mode, duration: TimeInterval, minimumGapToNextStep: TimeInterval = 0) {
        self.name = name
        self.mode = mode
        self.duration = duration
        self.minimumGapToNextStep = minimumGapToNextStep
    }

    public func step(id: UUID) -> Step {
        Step(id: id, name: name, mode: mode, duration: duration, minimumGapToNextStep: minimumGapToNextStep)
    }
}
