import Foundation

/// A structured fact learned from the user, for example `run.avoid = rain`.
public struct Preference: Codable, Sendable, Hashable {
    public var key: String
    public var value: String
    public var sourceSentence: String
    public var date: Date

    public init(key: String, value: String, sourceSentence: String, date: Date) {
        self.key = key
        self.value = value
        self.sourceSentence = sourceSentence
        self.date = date
    }
}
