import Foundation

/// The weather at a saved place, as far as planning needs it.
public protocol WeatherSource: Sendable {
    /// The day's weather at the place, or nil when it cannot be known.
    func condition(on day: Date, at place: Place) async -> WeatherCondition?
}
