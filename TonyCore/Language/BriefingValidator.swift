import Foundation

/// Checks a briefing against the plan it was written from. The model words; it must not invent.
public enum BriefingValidator {
    public enum Problem: Sendable, Hashable {
        case empty
        case tooLong
        /// Names a time of day that is not in the plan, in minutes after midnight.
        case unknownTime(minutes: Int)
        /// Names a task that is not planned today.
        case unplannedTask(String)
        /// Names none of the planned tasks.
        case namesNoTask
    }

    public static let maximumLength = 600

    /// What is wrong with the text; empty when it can be shown.
    public static func problems(in text: String, for request: BriefingRequest) -> [Problem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [.empty] }

        var problems: [Problem] = []
        if trimmed.count > maximumLength {
            problems.append(.tooLong)
        }
        let unknownTimes = minutesOfDay(in: trimmed).filter { minutes in
            // "6:00" may be the plan's 18:00 said the twelve-hour way.
            !request.allowedMinutes.contains(minutes) && !request.allowedMinutes.contains(minutes + 12 * 60)
        }
        problems += unknownTimes.sorted().map { .unknownTime(minutes: $0) }

        let plan = request.prompt()
        problems += request.otherTaskNames
            .filter { !$0.isEmpty && !mentions($0, in: plan) && mentions($0, in: trimmed) }
            .map { .unplannedTask($0) }
        if !request.items.isEmpty, !request.items.contains(where: { mentions($0.title, in: trimmed) }) {
            problems.append(.namesNoTask)
        }
        return problems
    }

    /// Every time of day written in the text ("18:00", "18h30", "6:30 PM", "6 pm", "18 h"), in minutes after midnight.
    public static func minutesOfDay(in text: String) -> Set<Int> {
        var found: Set<Int> = []
        for match in text.matches(of: /\b(\d{1,2})\s?[:h]\s?(\d{2})(\s?(am|pm|a\.m\.|p\.m\.))?/.ignoresCase()) {
            guard var hour = Int(match.1), let minute = Int(match.2), hour < 24, minute < 60 else { continue }
            if let half = match.4?.lowercased(), hour <= 12 {
                hour = hour % 12 + (half.hasPrefix("p") ? 12 : 0)
            }
            found.insert(hour * 60 + minute)
        }
        for match in text.matches(of: /\b(\d{1,2})\s?(am|pm|a\.m\.|p\.m\.)/.ignoresCase()) {
            if let hour = Int(match.1), (1...12).contains(hour) {
                let isAfternoon = match.2.lowercased().hasPrefix("p")
                found.insert((hour % 12 + (isAfternoon ? 12 : 0)) * 60)
            }
        }
        for match in text.matches(of: /\b(\d{1,2})\s?h\b/) {
            if let hour = Int(match.1), hour < 24 {
                found.insert(hour * 60)
            }
        }
        return found
    }

    /// Whether the text names the task, whatever the case and the accents. A multi-step title ("Laundry · Wash") counts by its task name.
    private static func mentions(_ name: String, in text: String) -> Bool {
        let taskName = name.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? name
        return text.range(of: taskName, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
