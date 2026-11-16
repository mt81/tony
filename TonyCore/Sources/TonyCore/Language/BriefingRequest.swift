import Foundation

/// Everything needed to word one day's briefing and to check the wording: the plan as text, already in the user's language,
/// and the facts a briefing may name.
public struct BriefingRequest: Sendable, Hashable {
    public struct Item: Sendable, Hashable {
        public var time: String
        public var title: String
        public var reason: String

        public init(time: String, title: String, reason: String) {
            self.time = time
            self.title = title
            self.reason = reason
        }
    }

    public var instructions: String
    /// Lines before the tasks: the day, the person's name.
    public var header: [String]
    public var items: [Item]
    /// Lines after the tasks: the busy blocks, or that nothing is planned.
    public var footer: [String]
    /// The times of day a briefing may name, in minutes after midnight: task starts and the edges of busy blocks.
    public var allowedMinutes: Set<Int>
    /// The user's tasks that are not planned today. A briefing must not name them.
    public var otherTaskNames: [String]
    /// The templated briefing, used when the model cannot give a valid one.
    public var fallback: String

    /// The prompt stays well under the model's context window: about four characters make a token.
    public static let characterBudget = 1200

    public init(
        instructions: String,
        header: [String],
        items: [Item],
        footer: [String],
        allowedMinutes: Set<Int>,
        otherTaskNames: [String],
        fallback: String
    ) {
        self.instructions = instructions
        self.header = header
        self.items = items
        self.footer = footer
        self.allowedMinutes = allowedMinutes
        self.otherTaskNames = otherTaskNames
        self.fallback = fallback
    }

    /// The plan as compact text. Over the budget, the reasons go first, then the last tasks.
    public func prompt(characterBudget: Int = BriefingRequest.characterBudget) -> String {
        func text(_ items: [Item], withReasons: Bool) -> String {
            let lines = items.map { withReasons ? "\($0.time) \($0.title). \($0.reason)" : "\($0.time) \($0.title)" }
            return (header + lines + footer).joined(separator: "\n")
        }
        let full = text(items, withReasons: true)
        if full.count <= characterBudget {
            return full
        }
        var kept = items
        while !kept.isEmpty, text(kept, withReasons: false).count > characterBudget {
            kept.removeLast()
        }
        return text(kept, withReasons: false)
    }
}
