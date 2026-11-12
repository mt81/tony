import Foundation
import Testing
@testable import TonyCore

/// Days are days of November 2026. In the fixture routine the 2nd (Monday) is a home day,
/// the 3rd (Tuesday) an office day and the 7th (Saturday) is not a working day.
private func interval(day: Int = 2, _ startHour: Int, _ startMinute: Int, _ endHour: Int, _ endMinute: Int) throws -> DateInterval {
    DateInterval(
        start: try Fixtures.november(day, hour: startHour, minute: startMinute),
        end: try Fixtures.november(day, hour: endHour, minute: endMinute)
    )
}

private func context(
    day: Int = 2,
    busyIntervals: [DateInterval] = [],
    status: DayStatus = .normal,
    conditions: DayConditions = DayConditions()
) throws -> DayContext {
    DayContext(
        routine: Fixtures.routine(),
        busyIntervals: busyIntervals,
        status: status,
        conditions: conditions,
        day: try Fixtures.november(day, hour: 8),
        calendar: Fixtures.calendar
    )
}

@Test func sampleDayGivesTheExpectedBlockList() throws {
    let busyIntervals = [
        try interval(13, 0, 13, 30),
        try interval(10, 0, 10, 20),
        try interval(10, 25, 10, 45),
        try interval(10, 45, 11, 0),
    ]

    let blocks = try context(busyIntervals: busyIntervals).blocks

    let expected = [
        DayContext.Block(interval: try interval(0, 0, 7, 0), location: .home, availability: .free, window: .night),
        DayContext.Block(interval: try interval(7, 0, 9, 0), location: .home, availability: .free, window: .morning),
        DayContext.Block(interval: try interval(9, 0, 10, 0), location: .home, availability: .partiallyAvailable, window: .workday),
        DayContext.Block(interval: try interval(10, 0, 11, 0), location: .home, availability: .busy, window: .workday, eventCount: 3),
        DayContext.Block(interval: try interval(11, 0, 13, 0), location: .home, availability: .partiallyAvailable, window: .workday),
        DayContext.Block(interval: try interval(13, 0, 13, 30), location: .home, availability: .busy, window: .workday, eventCount: 1),
        DayContext.Block(interval: try interval(13, 30, 17, 0), location: .home, availability: .partiallyAvailable, window: .workday),
        DayContext.Block(interval: try interval(17, 0, 23, 0), location: .home, availability: .free, window: .evening),
        DayContext.Block(
            interval: DateInterval(start: try Fixtures.november(2, hour: 23), end: try Fixtures.november(3)),
            location: .home,
            availability: .free,
            window: .night
        ),
    ]
    #expect(blocks == expected)
}

@Test(arguments: [
    (gapInMinutes: 14, expectedBusyBlocks: 1),
    (gapInMinutes: 15, expectedBusyBlocks: 2),
])
func eventsMergeOnlyWhenCloserThanFifteenMinutes(gapInMinutes: Int, expectedBusyBlocks: Int) throws {
    let busyIntervals = [
        try interval(10, 0, 10, 30),
        try interval(10, 30 + gapInMinutes, 11, 0),
    ]

    let busyBlocks = try context(busyIntervals: busyIntervals).blocks.filter { $0.availability == .busy }

    #expect(busyBlocks.count == expectedBusyBlocks)
}

@Test func overlappingEventsMergeAndKeepTheLatestEnd() throws {
    let busyIntervals = [
        try interval(10, 0, 12, 0),
        try interval(10, 30, 11, 0),
    ]

    let busyBlocks = try context(busyIntervals: busyIntervals).blocks.filter { $0.availability == .busy }

    #expect(busyBlocks.map(\.interval) == [try interval(10, 0, 12, 0)])
    #expect(busyBlocks.map(\.eventCount) == [2])
}

@Test func eventsAreClippedToTheDay() throws {
    let overnight = DateInterval(start: try Fixtures.november(1, hour: 22), end: try Fixtures.november(2, hour: 1))
    let yesterday = try interval(day: 1, 9, 0, 10, 0)

    let blocks = try context(busyIntervals: [overnight, yesterday]).blocks

    #expect(blocks.first?.interval == (try interval(0, 0, 1, 0)))
    #expect(blocks.first?.availability == .busy)
    #expect(blocks.filter { $0.availability == .busy }.count == 1)
}

@Test func blocksCoverTheWholeDayWithoutGaps() throws {
    let blocks = try context(busyIntervals: [try interval(16, 30, 17, 30)]).blocks

    #expect(blocks.first?.interval.start == (try Fixtures.november(2)))
    #expect(blocks.last?.interval.end == (try Fixtures.november(3)))
    for (block, next) in zip(blocks, blocks.dropFirst()) {
        #expect(block.interval.end == next.interval.start)
    }
}

@Test func officeDayIsAtTheOffice() throws {
    let blocks = try context(day: 3).blocks

    #expect(blocks.allSatisfy { $0.location == .office })
}

@Test func dayOutsideTheWorkingWeekIsFreeAtHome() throws {
    let blocks = try context(day: 7).blocks

    #expect(blocks.allSatisfy { $0.availability == .free && $0.location == .home })
    #expect(blocks.map(\.window) == [.night, .morning, .workday, .evening, .night])
}

@Test(arguments: [
    (status: DayStatus.normal, capacity: Capacity.full, location: Location.office),
    (status: DayStatus.offDay, capacity: Capacity.off, location: Location.office),
    (status: DayStatus.sick, capacity: Capacity.reduced, location: Location.office),
    (status: DayStatus.travelling, capacity: Capacity.reduced, location: Location.away),
])
func statusSetsCapacityAndTravellingMovesTheDayAway(status: DayStatus, capacity: Capacity, location: Location) throws {
    let dayContext = try context(day: 3, status: status)

    #expect(dayContext.capacity == capacity)
    #expect(dayContext.blocks.allSatisfy { $0.location == location })
}

@Test func conditionsArePassedThrough() throws {
    let conditions = DayConditions(weather: .rain, budgetIsTight: true)

    #expect(try context(conditions: conditions).conditions == conditions)
}

@Test func bedtimeAfterMidnightKeepsTheEveningUntilTheEndOfTheDay() throws {
    var routine = Fixtures.routine()
    routine.bedtime = DateComponents(hour: 0, minute: 30)

    let dayContext = DayContext(
        routine: routine,
        busyIntervals: [],
        status: .normal,
        conditions: DayConditions(),
        day: try Fixtures.november(2),
        calendar: Fixtures.calendar
    )

    #expect(dayContext.blocks.last?.window == .evening)
    #expect(dayContext.blocks.last?.interval.end == (try Fixtures.november(3)))
}

@Test func dayContextRoundTrips() throws {
    let dayContext = try context(busyIntervals: [try interval(10, 0, 11, 0)], status: .sick)

    let data = try JSONEncoder().encode(dayContext)

    #expect(try JSONDecoder().decode(DayContext.self, from: data) == dayContext)
}
