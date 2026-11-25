import MemberwiseInit

/// Where and when something fits. The empty value means anywhere, any time, any weather.
@MemberwiseInit(.public)
public struct Requirements: Codable, Sendable, Hashable {
    public var location: Location? = nil
    public var windows: Set<Window> = []
    /// The weather it can happen in; empty for any weather.
    public var neededWeather: Set<WeatherCondition> = []
    public var costsMoney: Bool = false
}

extension Requirements {
    private enum CodingKeys: String, CodingKey {
        case location, windows, neededWeather, costsMoney
    }

    /// Tasks saved before `neededWeather` existed have no such key; they read as any weather.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            location: try container.decodeIfPresent(Location.self, forKey: .location),
            windows: try container.decode(Set<Window>.self, forKey: .windows),
            neededWeather: try container.decodeIfPresent(Set<WeatherCondition>.self, forKey: .neededWeather) ?? [],
            costsMoney: try container.decode(Bool.self, forKey: .costsMoney)
        )
    }
}
