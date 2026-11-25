import MemberwiseInit

/// Where the user lives, as they named it, for the weather.
@MemberwiseInit(.public)
public struct Place: Codable, Sendable, Hashable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
}
