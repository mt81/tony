import Foundation
import Testing
@testable import TonyCore

private func expectRoundTrip<Value: Codable & Sendable & Equatable>(_ value: Value) throws {
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(Value.self, from: data)
    #expect(decoded == value)
}

@Test func taskWithStepsRequirementsAndDeadlineRoundTrips() throws {
    try expectRoundTrip(Fixtures.laundry())
}

@Test func taskWithoutOptionalFieldsRoundTrips() throws {
    let task = TonyTask(
        id: try Fixtures.identifier(5),
        name: "Renew passport",
        icon: "doc",
        kind: .oneTime,
        rank: 3,
        createdAt: try Fixtures.november(1)
    )
    try expectRoundTrip(task)
}

@Test(arguments: [
    Cadence.afterCompletion(days: 5),
    Cadence.weekdays([.monday, .thursday]),
    Cadence.timesPerWeek(3),
])
func cadenceRoundTrips(cadence: Cadence) throws {
    try expectRoundTrip(cadence)
}

@Test(arguments: Completion.Outcome.allCases)
func completionRoundTrips(outcome: Completion.Outcome) throws {
    let completion = Completion(
        id: try Fixtures.identifier(6),
        taskID: try Fixtures.identifier(1),
        stepID: try Fixtures.identifier(2),
        date: try Fixtures.november(3, hour: 8, minute: 30),
        outcome: outcome
    )
    try expectRoundTrip(completion)
}

@Test func routineRoundTrips() throws {
    try expectRoundTrip(Fixtures.routine())
}

@Test func preferenceRoundTrips() throws {
    let preference = Preference(
        key: "run.avoid",
        value: "rain",
        sourceSentence: "Not in the rain",
        date: try Fixtures.november(3)
    )
    try expectRoundTrip(preference)
}

@Test func contextDimensionsRoundTrip() throws {
    try expectRoundTrip(Location.allCases)
    try expectRoundTrip(Availability.allCases)
    try expectRoundTrip(Capacity.allCases)
    try expectRoundTrip(Window.allCases)
    try expectRoundTrip(WeatherCondition.allCases)
}
