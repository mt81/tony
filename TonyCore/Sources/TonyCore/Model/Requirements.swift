/// Where and when something fits. The empty value means anywhere, any time.
public struct Requirements: Codable, Sendable, Hashable {
    public var location: Location?
    public var availability: Availability?
    public var windows: Set<Window>
    public var avoidedWeather: Set<WeatherCondition>
    public var costsMoney: Bool

    public init(
        location: Location? = nil,
        availability: Availability? = nil,
        windows: Set<Window> = [],
        avoidedWeather: Set<WeatherCondition> = [],
        costsMoney: Bool = false
    ) {
        self.location = location
        self.availability = availability
        self.windows = windows
        self.avoidedWeather = avoidedWeather
        self.costsMoney = costsMoney
    }
}
