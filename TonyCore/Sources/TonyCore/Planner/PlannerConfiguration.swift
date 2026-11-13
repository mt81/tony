/// Every tunable value of the planner, in one place.
public struct PlannerConfiguration: Codable, Sendable, Hashable {
    public var fullCapacityCap = 4
    public var reducedCapacityCap = 2
    public var offCapacityCap = 0

    public var rankWeight = 1.0
    public var neglectWeight = 1.0
    public var goalPressureWeight = 1.0
    /// Neglect grows exponentially, so it is capped before it is weighed.
    public var maximumNeglect = 10.0

    public init() {}

    public func cap(for capacity: Capacity) -> Int {
        switch capacity {
        case .full: fullCapacityCap
        case .reduced: reducedCapacityCap
        case .off: offCapacityCap
        }
    }
}
