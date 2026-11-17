import Foundation
import SwiftData
import Testing
import TonyCore
@testable import TonyStore

private let referenceDate = Date(timeIntervalSince1970: 1_793_577_600)

private func task(_ name: String) -> TonyTask {
    TonyTask(
        id: UUID(),
        name: name,
        icon: "star",
        kind: .recurring,
        rank: 99,
        cadence: .weekdays([.monday, .thursday]),
        requirements: Requirements(location: .home, windows: [.evening], avoidedWeather: [.rain]),
        steps: [Step(id: UUID(), name: name, mode: .active, duration: 30 * 60)],
        mustHappenBy: referenceDate.addingTimeInterval(86_400),
        createdAt: referenceDate
    )
}

private func completion(of task: TonyTask, after seconds: TimeInterval = 0) -> Completion {
    Completion(id: UUID(), taskID: task.id, date: referenceDate.addingTimeInterval(seconds), outcome: .done)
}

/// Saves the named tasks in order and returns them as stored.
private func repository(with names: [String]) async throws -> (SwiftDataRepository, [TonyTask]) {
    let repository = try SwiftDataRepository.inMemory()
    for name in names {
        try await repository.save(task(name))
    }
    return (repository, try await repository.tasks())
}

@Test func newTasksAreAddedAtTheEndInRankOrder() async throws {
    let (_, tasks) = try await repository(with: ["Laundry", "Plants", "Gym"])

    #expect(tasks.map(\.name) == ["Laundry", "Plants", "Gym"])
    #expect(tasks.map(\.rank) == [0, 1, 2])
}

@Test func savedTaskComesBackUnchangedApartFromItsRank() async throws {
    let repository = try SwiftDataRepository.inMemory()
    var original = task("Laundry")

    try await repository.save(original)

    original.rank = 0
    #expect(try await repository.tasks() == [original])
}

@Test func savingAnExistingTaskUpdatesItAndKeepsItsRank() async throws {
    let (repository, tasks) = try await repository(with: ["Laundry", "Plants"])
    var plants = tasks[1]
    plants.name = "Water the plants"
    plants.cadence = .afterCompletion(days: 5)
    plants.rank = 42

    try await repository.save(plants)

    let stored = try await repository.tasks()
    #expect(stored.map(\.name) == ["Laundry", "Water the plants"])
    #expect(stored[1].cadence == .afterCompletion(days: 5))
    #expect(stored.map(\.rank) == [0, 1])
}

@Test func deletingATaskRemovesItAndItsCompletions() async throws {
    let (repository, tasks) = try await repository(with: ["Laundry", "Plants"])
    try await repository.save(completion(of: tasks[0]))
    try await repository.save(completion(of: tasks[1]))

    try await repository.deleteTask(id: tasks[0].id)

    #expect(try await repository.tasks().map(\.name) == ["Plants"])
    #expect(try await repository.completions().map(\.taskID) == [tasks[1].id])
}

@Test func reorderingPutsTheTasksInTheGivenOrder() async throws {
    let (repository, tasks) = try await repository(with: ["A", "B", "C"])

    try await repository.reorderTasks([tasks[2].id, tasks[0].id, tasks[1].id])

    let stored = try await repository.tasks()
    #expect(stored.map(\.name) == ["C", "A", "B"])
    #expect(stored.map(\.rank) == [0, 1, 2])
}

@Test func reorderingSomeTasksLeavesTheOthersInPlace() async throws {
    let (repository, tasks) = try await repository(with: ["A", "B", "C", "D", "E"])

    try await repository.reorderTasks([tasks[4].id, tasks[2].id, tasks[0].id])

    #expect(try await repository.tasks().map(\.name) == ["E", "B", "C", "D", "A"])
}

@Test func completionsComeBackOldestFirst() async throws {
    let (repository, tasks) = try await repository(with: ["Laundry"])
    let later = completion(of: tasks[0], after: 3600)
    let earlier = completion(of: tasks[0])

    try await repository.save(later)
    try await repository.save(earlier)

    #expect(try await repository.completions() == [earlier, later])
}

@Test func routineIsSavedAndReplaced() async throws {
    let repository = try SwiftDataRepository.inMemory()
    var routine = Routine(
        homeDays: [.monday, .friday],
        officeDays: [.tuesday, .wednesday, .thursday],
        workStart: DateComponents(hour: 9, minute: 0),
        workEnd: DateComponents(hour: 17, minute: 0),
        wakeTime: DateComponents(hour: 7, minute: 0),
        bedtime: DateComponents(hour: 23, minute: 0)
    )

    #expect(try await repository.routine() == nil)

    try await repository.save(routine)
    routine.officeDays = [.tuesday]
    try await repository.save(routine)

    #expect(try await repository.routine() == routine)
}

@Test func preferenceWithTheSameKeyIsReplaced() async throws {
    let repository = try SwiftDataRepository.inMemory()
    let rain = Preference(key: "run.avoid", value: "rain", sourceSentence: "Not in the rain", date: referenceDate)
    let snow = Preference(key: "run.avoid", value: "snow", sourceSentence: "Not in the snow", date: referenceDate)
    let lunch = Preference(key: "lunch.planned", value: "yes", sourceSentence: "Yes", date: referenceDate)

    try await repository.save(rain)
    try await repository.save(lunch)
    try await repository.save(snow)

    #expect(try await repository.preferences() == [lunch, snow])
}

@Test func dataIsThereForASecondRepositoryOnTheSameStore() async throws {
    let container = try SwiftDataRepository.container(ModelConfiguration(isStoredInMemoryOnly: true))
    let first = SwiftDataRepository(modelContainer: container)
    try await first.save(task("Laundry"))

    let second = SwiftDataRepository(modelContainer: container)

    #expect(try await second.tasks().map(\.name) == ["Laundry"])
}
