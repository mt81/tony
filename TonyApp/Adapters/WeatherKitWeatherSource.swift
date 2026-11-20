import CoreLocation
import TonyCore
import WeatherKit

/// The day's weather from WeatherKit, where the user roughly is.
/// It asks for location the first time it is needed, and reads the forecast at most once an hour.
actor WeatherKitWeatherSource: WeatherSource {
    private let calendar: Calendar
    private var session: CLServiceSession?
    private var latest: (day: Date, readAt: Date, condition: TonyCore::WeatherCondition)?

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func condition(on day: Date) async -> TonyCore::WeatherCondition? {
        let startOfDay = calendar.startOfDay(for: day)
        if let latest, latest.day == startOfDay, Date.now.timeIntervalSince(latest.readAt) < 3600 {
            return latest.condition
        }
        guard
            let location = await currentLocation(),
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay),
            let forecast = try? await WeatherService.shared.weather(for: location, including: .daily(startDate: startOfDay, endDate: endOfDay)),
            let dayWeather = forecast.first(where: { calendar.isDate($0.date, inSameDayAs: day) })
        else {
            return nil
        }
        let condition = TonyCore::WeatherCondition(dayWeather.condition)
        latest = (startOfDay, .now, condition)
        return condition
    }

    /// Where the user roughly is, or nil when location is refused or not found within ten seconds.
    /// The session stays open so the system prompt can still be answered after the ten seconds.
    private func currentLocation() async -> CLLocation? {
        if session == nil {
            session = CLServiceSession(authorization: .whenInUse)
        }
        return await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let location = update.location {
                            return location
                        }
                        if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                            return nil
                        }
                    }
                } catch {
                    return nil
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

extension TonyCore::WeatherCondition {
    /// Folds WeatherKit's many conditions into the four the planner knows.
    fileprivate init(_ condition: WeatherKit::WeatherCondition) {
        switch condition {
        case .clear, .mostlyClear, .hot, .frigid:
            self = .clear
        case .drizzle, .rain, .heavyRain, .sunShowers, .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms,
            .strongStorms, .tropicalStorm, .hurricane, .hail, .freezingDrizzle, .freezingRain:
            self = .rain
        case .snow, .heavySnow, .flurries, .sunFlurries, .blizzard, .blowingSnow, .sleet, .wintryMix:
            self = .snow
        default:
            self = .cloudy
        }
    }
}
