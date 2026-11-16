import Foundation
import TonyCore

/// One prompt of the model spikes (S1 briefing, S2 parsing) with what a good answer looks like.
/// The data is invented. Its text is for developers and for the model, so it is not in the String Catalog.
public struct ModelSpikeCase: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        /// S1: word this plan. The answer must name every task, and no time that is not in the plan.
        case briefing(taskNames: [String])
        /// S2: turn this sentence into a task. The name must contain the keyword, and the cadence must match.
        case parsing(nameKeyword: String, cadence: Cadence?)
    }

    public var id: String
    public var languageCode: String
    public var input: String
    public var kind: Kind

    /// S1 passes under this, on device.
    public static let latencyTarget = Duration.seconds(3)

    public static let all: [ModelSpikeCase] = [
        ModelSpikeCase(
            id: "S1 full day (en)",
            languageCode: "en",
            input: """
                Tuesday. Capacity: full.
                08:00 Water the plants. Why then: the first moment that fits.
                12:30 Laundry, start the wash. Why then: it runs on its own while you work.
                18:00 Gym. Why then: kept for the evening.
                Busy: 10:00 to 11:00, 3 meetings back to back.
                """,
            kind: .briefing(taskNames: ["plants", "laundry", "gym"])
        ),
        ModelSpikeCase(
            id: "S1 light day (en)",
            languageCode: "en",
            input: """
                Saturday. Capacity: reduced.
                10:00 Vacuum. Why then: 9 days since last time.
                Busy: nothing.
                """,
            kind: .briefing(taskNames: ["vacuum"])
        ),
        ModelSpikeCase(
            id: "S1 full day (fr)",
            languageCode: "fr",
            input: """
                Mardi. Capacité : pleine.
                08:00 Arroser les plantes. Pourquoi : le premier moment qui convient.
                12:30 Lessive, lancer la machine. Pourquoi : ça tourne tout seul pendant le travail.
                18:00 Sport. Pourquoi : gardé pour le soir.
                Occupé : 10:00 à 11:00, 3 réunions à la suite.
                """,
            kind: .briefing(taskNames: ["plantes", "lessive", "sport"])
        ),
        ModelSpikeCase(
            id: "S1 light day (fr)",
            languageCode: "fr",
            input: """
                Samedi. Capacité : réduite.
                10:00 Aspirateur. Pourquoi : 9 jours depuis la dernière fois.
                Occupé : rien.
                """,
            kind: .briefing(taskNames: ["aspirateur"])
        ),
        ModelSpikeCase(id: "S2 every N days (en)", languageCode: "en", input: "Water the plants every 5 days", kind: .parsing(nameKeyword: "plants", cadence: .afterCompletion(days: 5))),
        ModelSpikeCase(id: "S2 weekday (en)", languageCode: "en", input: "Take out the trash every Tuesday", kind: .parsing(nameKeyword: "trash", cadence: .weekdays([.tuesday]))),
        ModelSpikeCase(id: "S2 times a week (en)", languageCode: "en", input: "Go to the gym 3 times a week", kind: .parsing(nameKeyword: "gym", cadence: .timesPerWeek(3))),
        ModelSpikeCase(id: "S2 one-time (en)", languageCode: "en", input: "Renew my passport", kind: .parsing(nameKeyword: "passport", cadence: nil)),
        ModelSpikeCase(id: "S2 every N days (fr)", languageCode: "fr", input: "Arroser les plantes tous les 5 jours", kind: .parsing(nameKeyword: "plantes", cadence: .afterCompletion(days: 5))),
        ModelSpikeCase(id: "S2 weekday (fr)", languageCode: "fr", input: "Sortir les poubelles chaque mardi", kind: .parsing(nameKeyword: "poubelles", cadence: .weekdays([.tuesday]))),
        ModelSpikeCase(id: "S2 times a week (fr)", languageCode: "fr", input: "Aller à la salle de sport 3 fois par semaine", kind: .parsing(nameKeyword: "sport", cadence: .timesPerWeek(3))),
        ModelSpikeCase(id: "S2 one-time (fr)", languageCode: "fr", input: "Renouveler mon passeport", kind: .parsing(nameKeyword: "passeport", cadence: nil)),
    ]
}

/// What the model gave for a case, and how long it took.
public struct ModelSpikeAnswer: Sendable, Equatable {
    public enum Output: Sendable, Equatable {
        case briefing(String)
        case task(name: String, cadence: Cadence?)
        case failure(String)
    }

    public var output: Output
    public var duration: Duration

    public init(output: Output, duration: Duration) {
        self.output = output
        self.duration = duration
    }
}

extension ModelSpikeCase {
    /// What is wrong with the answer; empty when it passes.
    public func problems(with answer: ModelSpikeAnswer) -> [String] {
        switch (kind, answer.output) {
        case (_, .failure(let message)):
            return ["failed: \(message)"]
        case (.briefing(let taskNames), .briefing(let text)):
            var problems = taskNames
                .filter { !text.localizedCaseInsensitiveContains($0) }
                .map { "does not name \($0)" }
            let allowed = Self.minutesOfDay(in: input)
            let invented = Self.minutesOfDay(in: text).filter { minutes in
                // "6:00" may be the plan's 18:00 said the twelve-hour way.
                !allowed.contains(minutes) && !allowed.contains(minutes + 12 * 60)
            }
            problems += invented.sorted().map { "names \($0 / 60):\(String(format: "%02d", $0 % 60)), which is not in the plan" }
            if answer.duration > Self.latencyTarget {
                problems.append("slower than \(Self.latencyTarget.secondsText)")
            }
            return problems
        case (.parsing(let nameKeyword, let cadence), .task(let name, let parsedCadence)):
            var problems: [String] = []
            if !name.localizedCaseInsensitiveContains(nameKeyword) {
                problems.append("name has no \"\(nameKeyword)\"")
            }
            if parsedCadence != cadence {
                problems.append("cadence is not \(cadence.map { "\($0)" } ?? "none")")
            }
            return problems
        default:
            return ["answered with the wrong kind of output"]
        }
    }

    /// Every time of day written in the text ("18:00", "18h30", "6 pm"), as minutes after midnight.
    static func minutesOfDay(in text: String) -> Set<Int> {
        var found: Set<Int> = []
        for match in text.matches(of: /\b(\d{1,2})\s?[:h]\s?(\d{2})\b/) {
            if let hour = Int(match.1), let minute = Int(match.2), hour < 24, minute < 60 {
                found.insert(hour * 60 + minute)
            }
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
}

extension Duration {
    /// "1.84 s", whatever the device's locale: this is developer text.
    var secondsText: String {
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return String(format: "%.2f s", seconds)
    }
}
