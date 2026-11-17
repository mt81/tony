public enum Location: String, Codable, Sendable, Hashable, CaseIterable {
    case home
    case office
    case away
}

public enum Availability: String, Codable, Sendable, Hashable, CaseIterable {
    case free
    case partiallyAvailable
    case busy
}

public enum Capacity: String, Codable, Sendable, Hashable, CaseIterable {
    case full
    case reduced
    case off
}

public enum Window: String, Codable, Sendable, Hashable, CaseIterable {
    case morning
    case workday
    case evening
    case night
}

public enum WeatherCondition: String, Codable, Sendable, Hashable, CaseIterable {
    case clear
    case cloudy
    case rain
    case snow
}
