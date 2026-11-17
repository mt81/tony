import Foundation
import Testing
@testable import TonyCore

/// Days are days of November 2026: the 3rd is an office day, the 6th a home working day,
/// the 7th a Saturday that is free all day at home.
private func selectedNames(
    _ tasks: [TonyTask],
    completions: [Completion] = [],
    day: Int = 7,
    status: DayStatus = .normal,
    conditions: DayConditions = DayConditions(),
    configuration: PlannerConfiguration = PlannerConfiguration()
) throws -> [String] {
    Planner.select(
        tasks: tasks,
        completions: completions,
        context: try Fixtures.dayContext(day: day, status: status, conditions: conditions),
        now: try Fixtures.november(day, hour: 7),
        calendar: Fixtures.calendar,
        configuration: configuration
    )
    .map(\.task.name)
}

private func sixTasks() throws -> [TonyTask] {
    try (1...6).map { try Fixtures.task($0, "Task \($0)", rank: $0) }
}

@Test func officeDayYieldsNoHomeChores() throws {
    let tasks = [
        try Fixtures.task(1, "Vacuum", rank: 0, requirements: Requirements(location: .home)),
        try Fixtures.task(2, "Call the bank", rank: 1),
    ]

    #expect(try selectedNames(tasks, day: 3) == ["Call the bank"])
    #expect(try selectedNames(tasks, day: 7) == ["Vacuum", "Call the bank"])
}

@Test func offStatusYieldsNone() throws {
    #expect(try selectedNames(sixTasks(), status: .offDay).isEmpty)
}

@Test func deadlineTasksBypassTheCap() throws {
    let deadline = try Fixtures.task(7, "Tax return", rank: 9, cadence: nil, mustHappenBy: try Fixtures.november(8))
    let tasks = try sixTasks() + [deadline]

    #expect(try selectedNames(tasks, status: .offDay) == ["Tax return"])
    #expect(try selectedNames(tasks) == ["Tax return", "Task 1", "Task 2", "Task 3", "Task 4"])
}

@Test(arguments: [
    (status: DayStatus.normal, expectedCount: 4),
    (status: DayStatus.sick, expectedCount: 2),
    (status: DayStatus.travelling, expectedCount: 2),
    (status: DayStatus.offDay, expectedCount: 0),
])
func capacityCapsTheNumberOfTasks(status: DayStatus, expectedCount: Int) throws {
    #expect(try selectedNames(sixTasks(), status: status).count == expectedCount)
}

@Test func capsComeFromTheConfiguration() throws {
    var configuration = PlannerConfiguration()
    configuration.fullCapacityCap = 1

    #expect(try selectedNames(sixTasks(), configuration: configuration) == ["Task 1"])
}

@Test func neglectOutweighsRank() throws {
    let recent = try Fixtures.task(1, "Top rank, just due", rank: 0)
    let neglected = try Fixtures.task(2, "Low rank, long overdue", rank: 5)
    let doneOnTheSecond = Completion(id: UUID(), taskID: recent.id, date: try Fixtures.november(2), outcome: .done)

    let names = try selectedNames([recent, neglected], completions: [doneOnTheSecond])

    #expect(names == ["Low rank, long overdue", "Top rank, just due"])
}

@Test func goalPressureRisesAsTheWeekRunsOut() throws {
    let chore = try Fixtures.task(1, "Chore", rank: 0, cadence: .weekdays([.saturday]))
    let goal = try Fixtures.task(2, "Gym", rank: 3, cadence: .timesPerWeek(4))
    var configuration = PlannerConfiguration()
    configuration.fullCapacityCap = 1

    #expect(try selectedNames([chore, goal], day: 7, configuration: configuration) == ["Gym"])

    let threeSessions = try [2, 3, 4].map { day in
        Completion(id: UUID(), taskID: goal.id, date: try Fixtures.november(day), outcome: .done)
    }
    #expect(try selectedNames([chore, goal], completions: threeSessions, day: 7, configuration: configuration) == ["Chore"])
}

@Test func notTodayExcludesATaskUnlessItHasADeadline() throws {
    let chore = try Fixtures.task(1, "Chore")
    let deadline = try Fixtures.task(2, "Tax return", cadence: nil, mustHappenBy: try Fixtures.november(8))
    let refusals = try [chore, deadline].map { task in
        Completion(id: UUID(), taskID: task.id, date: try Fixtures.november(7, hour: 6), outcome: .notToday)
    }

    #expect(try selectedNames([chore, deadline], completions: refusals) == ["Tax return"])
}

@Test func taskDoneTodayIsNotSuggestedAgain() throws {
    let goal = try Fixtures.task(1, "Gym", cadence: .timesPerWeek(4))
    let doneThisMorning = Completion(id: UUID(), taskID: goal.id, date: try Fixtures.november(7, hour: 6), outcome: .done)

    #expect(try selectedNames([goal], completions: [doneThisMorning]).isEmpty)
}

@Test func weatherAndBudgetExcludeTasks() throws {
    let run = try Fixtures.task(1, "Run", rank: 0, requirements: Requirements(avoidedWeather: [.rain]))
    let haircut = try Fixtures.task(2, "Haircut", rank: 1, requirements: Requirements(costsMoney: true))
    let walk = try Fixtures.task(3, "Walk", rank: 2)
    let tasks = [run, haircut, walk]

    #expect(try selectedNames(tasks, conditions: DayConditions(weather: .rain)) == ["Haircut", "Walk"])
    #expect(try selectedNames(tasks, conditions: DayConditions(budgetIsTight: true)) == ["Run", "Walk"])
    #expect(try selectedNames(tasks, conditions: DayConditions(weather: .clear)) == ["Run", "Haircut", "Walk"])
}

@Test func activeStepsNeedFreeTimeAndBackgroundStepsFitWorkHours() throws {
    let duringWork = Requirements(windows: [.workday])
    let active = Step(id: try Fixtures.identifier(100), name: "Vacuum", mode: .active, duration: 30 * 60)
    let background = Step(id: try Fixtures.identifier(200), name: "Wash", mode: .background, duration: 30 * 60)
    let tasks = [
        try Fixtures.task(1, "Vacuum", rank: 0, requirements: duringWork, steps: [active]),
        try Fixtures.task(2, "Laundry", rank: 1, requirements: duringWork, steps: [background]),
    ]

    #expect(try selectedNames(tasks, day: 6) == ["Laundry"])
}

@Test func stepsDoNotFitTheNightOrABlockThatIsTooShort() throws {
    let allDay = Step(id: try Fixtures.identifier(100), name: "Deep clean", mode: .active, duration: 9 * 3600)
    let short = Step(id: try Fixtures.identifier(200), name: "Tidy", mode: .active, duration: 6 * 3600)
    let tasks = [
        try Fixtures.task(1, "Deep clean", rank: 0, steps: [allDay]),
        try Fixtures.task(2, "Tidy", rank: 1, steps: [short]),
    ]

    #expect(try selectedNames(tasks) == ["Tidy"])
}

@Test func stepsDoneTodayAreNotRemaining() throws {
    let task = try Fixtures.laundry()
    let washDone = Completion(
        id: UUID(),
        taskID: task.id,
        stepID: task.steps[0].id,
        date: try Fixtures.november(7, hour: 6),
        outcome: .done
    )

    let candidates = Planner.candidates(
        tasks: [task],
        completions: [washDone],
        context: try Fixtures.dayContext(day: 7),
        now: try Fixtures.november(7, hour: 7),
        calendar: Fixtures.calendar
    )

    #expect(candidates.first?.remainingSteps.map(\.name) == ["Dry", "Fold"])
}
