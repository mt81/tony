import Foundation
import TonyCore

/// The day's weather from MET Norway's free forecast (api.met.no) at the saved place.
/// It sends only the coordinates, rounded to about 10 km, and reads the forecast at most once an hour.
actor MetNorwayWeatherSource: WeatherSource {
    private let calendar: Calendar
    private var latest: (day: Date, place: Place, readAt: Date, condition: WeatherCondition)?

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func condition(on day: Date, at place: Place) async -> WeatherCondition? {
        let startOfDay = calendar.startOfDay(for: day)
        if let latest, latest.day == startOfDay, latest.place == place, Date.now.timeIntervalSince(latest.readAt) < 3600 {
            return latest.condition
        }
        guard
            let forecast = await forecast(at: place),
            let condition = Self.mostFrequentCondition(in: forecast, on: day, calendar: calendar)
        else {
            return nil
        }
        latest = (startOfDay, place, .now, condition)
        return condition
    }

    private func forecast(at place: Place) async -> Forecast? {
        var components = URLComponents(string: "https://api.met.no/weatherapi/locationforecast/2.0/compact")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.1f", place.latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.1f", place.longitude)),
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        // MET Norway blocks requests that don't name the app and a contact.
        request.setValue("Tony/1.0 github.com/mt81/tony", forHTTPHeaderField: "User-Agent")
        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200
        else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Forecast.self, from: data)
    }

    /// The condition of most of the day's forecast hours; the more severe one wins a tie.
    private static func mostFrequentCondition(in forecast: Forecast, on day: Date, calendar: Calendar) -> WeatherCondition? {
        let conditions = forecast.properties.timeseries
            .filter { calendar.isDate($0.time, inSameDayAs: day) }
            .compactMap { $0.data.next1Hours.map { WeatherCondition(symbol: $0.summary.symbolCode) } }
        let counts = Dictionary(conditions.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { ($0.value, $0.key.severity) < ($1.value, $1.key.severity) }?.key
    }
}

private struct Forecast: Decodable {
    struct Properties: Decodable {
        var timeseries: [Entry]
    }

    struct Entry: Decodable {
        var time: Date
        var data: EntryData
    }

    struct EntryData: Decodable {
        var next1Hours: Period?
    }

    struct Period: Decodable {
        var summary: Summary
    }

    struct Summary: Decodable {
        var symbolCode: String
    }

    var properties: Properties
}

extension WeatherCondition {
    /// Folds MET Norway's 41 symbol codes (`lightrainshowers_day`, `heavysleetandthunder`…) into nine kinds:
    /// light, heavy and showers fold in, and thunder wins over what falls with it.
    fileprivate init(symbol: String) {
        self =
            if symbol.contains("thunder") { .thunder }
            else if symbol.contains("snow") { .snow }
            else if symbol.contains("sleet") { .sleet }
            else if symbol.contains("rain") { .rain }
            else if symbol.hasPrefix("clearsky") { .clear }
            else if symbol.hasPrefix("fair") { .fair }
            else if symbol.hasPrefix("partlycloudy") { .partlyCloudy }
            else if symbol.hasPrefix("fog") { .fog }
            else { .cloudy }
    }

    fileprivate var severity: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}
