import Foundation
import SwiftData
import TonyCore

@ModelActor
public actor SwiftDataRepository: Repository {
    /// The store shared by the app and the widget extension.
    public static func appGroup() throws -> SwiftDataRepository {
        let configuration = ModelConfiguration(groupContainer: .identifier(TonyCore.appGroupIdentifier))
        return SwiftDataRepository(modelContainer: try container(configuration))
    }

    public static func inMemory() throws -> SwiftDataRepository {
        SwiftDataRepository(modelContainer: try container(ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    static func container(_ configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: TaskRecord.self, CompletionRecord.self, RoutineRecord.self, PreferenceRecord.self,
            configurations: configuration
        )
    }

    // MARK: Tasks

    public func tasks() throws -> [TonyTask] {
        try taskRecords().map { record in
            var task = try JSONDecoder().decode(TonyTask.self, from: record.json)
            task.rank = record.rank
            return task
        }
    }

    public func save(_ task: TonyTask) throws {
        let records = try taskRecords()
        let json = try JSONEncoder().encode(task)
        if let record = records.first(where: { $0.id == task.id }) {
            record.json = json
        } else {
            let lastRank = records.last?.rank ?? -1
            modelContext.insert(TaskRecord(id: task.id, rank: lastRank + 1, json: json))
        }
        try modelContext.save()
    }

    public func deleteTask(id: UUID) throws {
        for record in try taskRecords() where record.id == id {
            modelContext.delete(record)
        }
        for record in try completionRecords() where record.taskID == id {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    public func reorderTasks(_ orderedIDs: [UUID]) throws {
        let records = try taskRecords().filter { orderedIDs.contains($0.id) }
        let ranks = records.map(\.rank)
        let reordered = orderedIDs.compactMap { id in records.first { $0.id == id } }
        for (record, rank) in zip(reordered, ranks) {
            record.rank = rank
        }
        try modelContext.save()
    }

    // MARK: Completions

    public func completions() throws -> [Completion] {
        try completionRecords().map { try JSONDecoder().decode(Completion.self, from: $0.json) }
    }

    public func save(_ completion: Completion) throws {
        let json = try JSONEncoder().encode(completion)
        if let record = try completionRecords().first(where: { $0.id == completion.id }) {
            record.taskID = completion.taskID
            record.date = completion.date
            record.json = json
        } else {
            modelContext.insert(CompletionRecord(id: completion.id, taskID: completion.taskID, date: completion.date, json: json))
        }
        try modelContext.save()
    }

    // MARK: Routine

    public func routine() throws -> Routine? {
        try modelContext.fetch(FetchDescriptor<RoutineRecord>()).first
            .map { try JSONDecoder().decode(Routine.self, from: $0.json) }
    }

    public func save(_ routine: Routine) throws {
        let json = try JSONEncoder().encode(routine)
        if let record = try modelContext.fetch(FetchDescriptor<RoutineRecord>()).first {
            record.json = json
        } else {
            modelContext.insert(RoutineRecord(json: json))
        }
        try modelContext.save()
    }

    // MARK: Preferences

    public func preferences() throws -> [Preference] {
        try modelContext.fetch(FetchDescriptor<PreferenceRecord>(sortBy: [SortDescriptor(\.key)]))
            .map { try JSONDecoder().decode(Preference.self, from: $0.json) }
    }

    public func save(_ preference: Preference) throws {
        let json = try JSONEncoder().encode(preference)
        let records = try modelContext.fetch(FetchDescriptor<PreferenceRecord>())
        if let record = records.first(where: { $0.key == preference.key }) {
            record.json = json
        } else {
            modelContext.insert(PreferenceRecord(key: preference.key, json: json))
        }
        try modelContext.save()
    }

    // MARK: Records

    private func taskRecords() throws -> [TaskRecord] {
        try modelContext.fetch(FetchDescriptor<TaskRecord>(sortBy: [SortDescriptor(\.rank)]))
    }

    private func completionRecords() throws -> [CompletionRecord] {
        try modelContext.fetch(FetchDescriptor<CompletionRecord>(sortBy: [SortDescriptor(\.date)]))
    }
}
