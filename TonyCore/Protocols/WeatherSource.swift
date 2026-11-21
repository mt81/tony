import Foundation

/// The weather where the user is, as far as planning needs it.
public protocol WeatherSource: Sendable {
    /// The day's weather, or nil when it cannot be known: no location access, no location or no network.
    func condition(on day: Date) async -> WeatherCondition?
}
