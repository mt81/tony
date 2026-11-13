import Foundation
import SwiftData

// Each record keeps its domain value as JSON, plus the few columns the store sorts or looks up by.

@Model
final class TaskRecord {
    @Attribute(.unique) var id: UUID
    var rank: Int
    var json: Data

    init(id: UUID, rank: Int, json: Data) {
        self.id = id
        self.rank = rank
        self.json = json
    }
}

@Model
final class CompletionRecord {
    @Attribute(.unique) var id: UUID
    var taskID: UUID
    var date: Date
    var json: Data

    init(id: UUID, taskID: UUID, date: Date, json: Data) {
        self.id = id
        self.taskID = taskID
        self.date = date
        self.json = json
    }
}

@Model
final class RoutineRecord {
    var json: Data

    init(json: Data) {
        self.json = json
    }
}

@Model
final class PreferenceRecord {
    @Attribute(.unique) var key: String
    var json: Data

    init(key: String, json: Data) {
        self.key = key
        self.json = json
    }
}
