import Foundation
import Testing
@testable import TonyCore

/// The laundry day is Monday 2 November 2026, a home working day: up at 8:30, work 9:00 to 17:00,
/// three meetings back to back from 10:00 to 11:00 and one at 13:00.
private struct LaundryDay {
    let laundry: TonyTask
    let context: DayContext

    init() throws {
        var task = try Fixtures.laundry()
        task.mustHappenBy = nil
        laundry = task

        var routine = Fixtures.routine()
        routine.wakeTime = DateComponents(hour: 8, minute: 30)
        context = try Fixtures.dayContext(
            day: 2,
            routine: routine,
            busyIntervals: [
                DateInterval(start: try Fixtures.november(2, hour: 10), duration: 20 * 60),
                DateInterval(start: try Fixtures.november(2, hour: 10, minute: 20), duration: 20 * 60),
                DateInterval(start: try Fixtures.november(2, hour: 10, minute: 40), duration: 20 * 60),
                DateInterval(start: try Fixtures.november(2, hour: 13), duration: 30 * 60),
            ]
        )
    }

    func plan(at hour: Int, minute: Int = 0, completions: [Completion] = []) throws -> DayPlan {
        Planner.plan(
            tasks: [laundry],
            completions: completions,
            context: context,
            now: try Fixtures.november(2, hour: hour, minute: minute),
            calendar: Fixtures.calendar
        )
    }

    func item(_ stepName: String, in plan: DayPlan) throws -> DayPlan.Item {
        let step = try #require(laundry.steps.first { $0.name == stepName })
        return try #require(plan.items.first { $0.stepID == step.id })
    }
}

private func time(_ hour: Int, _ minute: Int = 0) throws -> Date {
    try Fixtures.november(2, hour: hour, minute: minute)
}

@Test func laundryDayIsWashBeforeTenDryAfterElevenFoldInTheEvening() throws {
    let day = try LaundryDay()

    let plan = try day.plan(at: 7)

    let expected = [
        DayPlan.Item(
            taskID: day.laundry.id,
            stepID: day.laundry.steps[0].id,
            interval: DateInterval(start: try time(9), end: try time(9, 45)),
            latestStart: try time(20, 30),
            reason: .beforeBlock
        ),
        DayPlan.Item(
            taskID: day.laundry.id,
            stepID: day.laundry.steps[1].id,
            interval: DateInterval(start: try time(11), end: try time(12)),
            latestStart: try time(21, 15),
            reason: .afterBlock
        ),
        DayPlan.Item(
            taskID: day.laundry.id,
            stepID: day.laundry.steps[2].id,
            interval: DateInterval(start: try time(17), end: try time(17, 15)),
            latestStart: try time(22, 45),
            reason: .needsEvening
        ),
    ]
    #expect(plan.items == expected)
}

@Test func replanningAtTwoDropsTheMorning() throws {
    let day = try LaundryDay()

    let plan = try day.plan(at: 14)

    #expect(plan.items.map(\.interval.start) == [try time(14), try time(14, 45), try time(17)])
    #expect(try plan.items.allSatisfy { $0.interval.start >= (try time(14)) })
}

@Test func doneStepIsNotPlannedAgainAndTheNextOneWaitsForItToFinish() throws {
    let day = try LaundryDay()
    let wash = try day.item("Wash", in: try day.plan(at: 7))

    let completions = Planner.completions(for: .done, on: wash, of: day.laundry, at: try time(9, 30))
    let plan = try day.plan(at: 9, minute: 30, completions: completions)

    #expect(completions.map(\.stepID) == [wash.stepID])
    #expect(plan.items.count == 2)
    #expect(try day.item("Dry", in: plan).interval.start == (try time(11)))
}

@Test func doneOnTheLastStepCompletesTheTask() throws {
    let day = try LaundryDay()
    let fold = try day.item("Fold", in: try day.plan(at: 7))

    let completions = Planner.completions(for: .done, on: fold, of: day.laundry, at: try time(17, 10))

    #expect(completions.map(\.stepID) == [fold.stepID, nil])
    #expect(try day.plan(at: 18, completions: completions).items.isEmpty)
    #expect(!day.laundry.isDue(completions: completions, on: try Fixtures.november(3), calendar: Fixtures.calendar))
}

@Test func laterMovesTheStepToTheNextFittingBlock() throws {
    let day = try LaundryDay()
    let wash = try day.item("Wash", in: try day.plan(at: 7))

    let completions = Planner.completions(for: .later, on: wash, of: day.laundry, at: try time(9, 5))
    let plan = try day.plan(at: 9, minute: 5, completions: completions)

    #expect(plan.items.map(\.interval.start) == [try time(11), try time(11, 45), try time(17)])
}

@Test func notTodayRemovesTheTaskFromThePlan() throws {
    let day = try LaundryDay()
    let wash = try day.item("Wash", in: try day.plan(at: 7))

    let completions = Planner.completions(for: .notToday, on: wash, of: day.laundry, at: try time(9))

    #expect(try day.plan(at: 9, completions: completions).items.isEmpty)
}

@Test func taskWhoseStepsCannotFitInOrderIsLeftOut() throws {
    let day = try LaundryDay()

    #expect(try day.plan(at: 22, minute: 30).items.isEmpty)
}

@Test func activeStepsDoNotOverlapButBackgroundStepsMay() throws {
    func plannedStarts(mode: Step.Mode) throws -> [Date] {
        let tasks = try (1...2).map { number in
            let step = Step(id: try Fixtures.identifier(number * 100), name: "Step", mode: mode, duration: 30 * 60)
            return try Fixtures.task(number, "Task \(number)", rank: number, steps: [step])
        }
        return Planner.plan(
            tasks: tasks,
            completions: [],
            context: try Fixtures.dayContext(day: 7),
            now: try Fixtures.november(7, hour: 7),
            calendar: Fixtures.calendar
        )
        .items.map(\.interval.start)
    }

    #expect(try plannedStarts(mode: .active) == [try Fixtures.november(7, hour: 7), try Fixtures.november(7, hour: 7, minute: 30)])
    #expect(try plannedStarts(mode: .background) == [try Fixtures.november(7, hour: 7), try Fixtures.november(7, hour: 7)])
}

@Test func finishingATaskEarlyMakesRoomForTheNextCandidate() throws {
    let tasks = try (1...2).map { try Fixtures.task($0, "Task \($0)", rank: $0) }
    var configuration = PlannerConfiguration()
    configuration.fullCapacityCap = 1

    func plan(completions: [Completion]) throws -> DayPlan {
        Planner.plan(
            tasks: tasks,
            completions: completions,
            context: try Fixtures.dayContext(day: 7),
            now: try Fixtures.november(7, hour: 8),
            calendar: Fixtures.calendar,
            configuration: configuration
        )
    }

    let first = try #require(try plan(completions: []).items.first)
    let done = Planner.completions(for: .done, on: first, of: tasks[0], at: try Fixtures.november(7, hour: 8))

    #expect(first.taskID == tasks[0].id)
    #expect(try plan(completions: done).items.map(\.taskID) == [tasks[1].id])
}

@Test func dayPlanRoundTrips() throws {
    let plan = try LaundryDay().plan(at: 7)

    let data = try JSONEncoder().encode(plan)

    #expect(try JSONDecoder().decode(DayPlan.self, from: data) == plan)
}
