import MemberwiseInit

/// Where and when something fits. The empty value means anywhere, any time.
@MemberwiseInit(.public)
public struct Requirements: Codable, Sendable, Hashable {
    public var location: Location? = nil
    public var windows: Set<Window> = []
    public var avoidedWeather: Set<WeatherCondition> = []
    public var costsMoney: Bool = false
}
