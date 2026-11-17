import Foundation
import Testing
@testable import TonyCore

/// Days are days of November 2026: the 2nd is a Monday, and weeks start on Monday.
struct CadenceCase: Sendable, CustomTestStringConvertible {
    var testDescription: String
    var cadence: Cadence?
    var created = 1
    var done: [Int] = []
    /// Days with a later, a not today and a skipped completion, none of which counts as done.
    var unfinished: [Int] = []
    var on: Int
    var isDue: Bool
    var neglect = 0.0

    init(
        _ testDescription: String,
        _ cadence: Cadence?,
        done: [Int] = [],
        unfinished: [Int] = [],
        on: Int,
        isDue: Bool,
        neglect: Double = 0
    ) {
        self.testDescription = testDescription
        self.cadence = cadence
        self.done = done
        self.unfinished = unfinished
        self.on = on
        self.isDue = isDue
        self.neglect = neglect
    }

    func task() throws -> TonyTask {
        TonyTask(
            id: try Fixtures.identifier(1),
            name: "Water the plants",
            icon: "leaf",
            kind: .recurring,
            rank: 0,
            cadence: cadence,
            createdAt: try Fixtures.november(created)
        )
    }

    func completions() throws -> [Completion] {
        let taskID = try Fixtures.identifier(1)
        var completions: [Completion] = []
        for day in done {
            let date = try Fixtures.november(day, hour: 18)
            completions.append(Completion(id: UUID(), taskID: taskID, date: date, outcome: .done))
        }
        for day in unfinished {
            let date = try Fixtures.november(day, hour: 18)
            for outcome in [Completion.Outcome.later, .notToday, .skipped] {
                completions.append(Completion(id: UUID(), taskID: taskID, date: date, outcome: outcome))
            }
        }
        return completions
    }
}

private let everyFiveDays = Cadence.afterCompletion(days: 5)
private let mondayAndThursday = Cadence.weekdays([.monday, .thursday])
private let threePerWeek = Cadence.timesPerWeek(3)

private let cadenceCases: [CadenceCase] = [
    CadenceCase("after completion, never done, creation day", everyFiveDays, on: 1, isDue: true),
    CadenceCase("after completion, never done, 5 days in", everyFiveDays, on: 6, isDue: true, neglect: expm1(5.0 / 5)),
    CadenceCase("after completion, done, day before due", everyFiveDays, done: [2], on: 6, isDue: false),
    CadenceCase("after completion, done, due day", everyFiveDays, done: [2], on: 7, isDue: true),
    CadenceCase("after completion, done early, old due day", everyFiveDays, done: [2, 4], on: 7, isDue: false),
    CadenceCase("after completion, done early, new due day", everyFiveDays, done: [2, 4], on: 9, isDue: true),
    CadenceCase("after completion, done late, old rhythm", everyFiveDays, done: [2, 10], on: 12, isDue: false),
    CadenceCase("after completion, done late, new due day", everyFiveDays, done: [2, 10], on: 15, isDue: true),
    CadenceCase(
        "after completion, skipped",
        everyFiveDays, done: [2], unfinished: [7, 8], on: 9, isDue: true, neglect: expm1(2.0 / 5)
    ),

    CadenceCase("weekdays, never done, before first weekday", mondayAndThursday, on: 1, isDue: false),
    CadenceCase("weekdays, never done, first weekday", mondayAndThursday, on: 2, isDue: true),
    CadenceCase("weekdays, done on the day, next day", mondayAndThursday, done: [2], on: 3, isDue: false),
    CadenceCase("weekdays, done on the day, next weekday", mondayAndThursday, done: [2], on: 5, isDue: true),
    CadenceCase("weekdays, done early, still due on the day", mondayAndThursday, done: [2, 4], on: 5, isDue: true),
    CadenceCase("weekdays, late", mondayAndThursday, on: 3, isDue: true, neglect: expm1(1.0 / 3.5)),
    CadenceCase("weekdays, done late", mondayAndThursday, done: [3], on: 4, isDue: false),
    CadenceCase("weekdays, done late, next weekday", mondayAndThursday, done: [3], on: 5, isDue: true),
    CadenceCase("weekdays, skipped", mondayAndThursday, unfinished: [2], on: 4, isDue: true, neglect: expm1(2.0 / 3.5)),

    CadenceCase("per week, never done", threePerWeek, on: 2, isDue: true),
    CadenceCase("per week, short of quota", threePerWeek, done: [2, 3], on: 4, isDue: true),
    CadenceCase("per week, quota met early", threePerWeek, done: [2, 3, 4], on: 5, isDue: false),
    CadenceCase("per week, new week", threePerWeek, done: [2, 3, 4], on: 9, isDue: true),
    CadenceCase("per week, late in the week", threePerWeek, done: [8], on: 8, isDue: true),
    CadenceCase("per week, skipped", threePerWeek, unfinished: [2, 3, 4], on: 5, isDue: true),
    CadenceCase(
        "per week, a week without a session",
        threePerWeek, done: [2], on: 12, isDue: true, neglect: expm1(3.0 / (7.0 / 3))
    ),

    CadenceCase("one-time, never done", nil, on: 20, isDue: true),
    CadenceCase("one-time, done", nil, done: [3], on: 20, isDue: false),
]

@Test(arguments: cadenceCases)
func dueAndNeglect(cadenceCase: CadenceCase) throws {
    let task = try cadenceCase.task()
    let completions = try cadenceCase.completions()
    let day = try Fixtures.november(cadenceCase.on, hour: 8)

    #expect(task.isDue(completions: completions, on: day, calendar: Fixtures.calendar) == cadenceCase.isDue)

    let neglect = task.neglect(completions: completions, on: day, calendar: Fixtures.calendar)
    #expect(abs(neglect - cadenceCase.neglect) < 1e-9)
}

@Test func sameDelayWeighsMoreOnAShortCadence() throws {
    let day = try Fixtures.november(18)
    let weekly = try CadenceCase("weekly", .afterCompletion(days: 7), done: [1], on: 18, isDue: true).task()
    let monthly = try CadenceCase("monthly", .afterCompletion(days: 30), on: 11, isDue: true).task()
    let doneOnTheFirst = [
        Completion(id: UUID(), taskID: weekly.id, date: try Fixtures.november(1), outcome: .done),
    ]

    let weeklyNeglect = weekly.neglect(completions: doneOnTheFirst, on: day, calendar: Fixtures.calendar)
    let monthlyNeglect = monthly.neglect(completions: [], on: try Fixtures.november(11), calendar: Fixtures.calendar)

    #expect(abs(weeklyNeglect - expm1(10.0 / 7)) < 1e-9)
    #expect(abs(monthlyNeglect - expm1(10.0 / 30)) < 1e-9)
    #expect(weeklyNeglect > monthlyNeglect)
}

@Test func stepsOtherTasksAndLaterDaysDoNotCountAsDone() throws {
    let task = try CadenceCase("task", everyFiveDays, on: 7, isDue: true).task()
    let completions = [
        Completion(id: UUID(), taskID: task.id, date: try Fixtures.november(2), outcome: .done),
        Completion(id: UUID(), taskID: task.id, stepID: try Fixtures.identifier(2), date: try Fixtures.november(6), outcome: .done),
        Completion(id: UUID(), taskID: try Fixtures.identifier(9), date: try Fixtures.november(6), outcome: .done),
        Completion(id: UUID(), taskID: task.id, date: try Fixtures.november(8), outcome: .done),
    ]

    #expect(task.isDue(completions: completions, on: try Fixtures.november(7), calendar: Fixtures.calendar))
}

@Test func weeklyQuotaProgressCountsThisWeekOnly() throws {
    let task = try CadenceCase("quota", threePerWeek, on: 12, isDue: true).task()
    let completions = try [4, 9, 11, 13].map { day in
        Completion(id: UUID(), taskID: task.id, date: try Fixtures.november(day, hour: 18), outcome: .done)
    }

    let progress = task.weeklyQuotaProgress(completions: completions, on: try Fixtures.november(12), calendar: Fixtures.calendar)

    #expect(progress == WeeklyQuotaProgress(done: 2, target: 3, daysLeft: 4))
}

@Test func weeklyQuotaProgressIsNilForOtherCadences() throws {
    let task = try CadenceCase("no quota", everyFiveDays, on: 2, isDue: true).task()

    #expect(task.weeklyQuotaProgress(completions: [], on: try Fixtures.november(2), calendar: Fixtures.calendar) == nil)
}

@Test func dueDayIsTheNextDayTheTaskComesDue() throws {
    let task = try CadenceCase("due day", everyFiveDays, on: 3, isDue: false).task()
    let done = [Completion(id: UUID(), taskID: task.id, date: try Fixtures.november(2, hour: 18), outcome: .done)]

    #expect(task.dueDay(completions: done, on: try Fixtures.november(3), calendar: Fixtures.calendar) == (try Fixtures.november(7)))
}
