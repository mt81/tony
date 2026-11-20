import Foundation
import MemberwiseInit
import TonyCore

/// One fixed input of the evaluation set and what a good answer must have. The model cannot be pinned to a version,
/// so the set is run on each iOS release and the pass rate compared with the recorded baseline.
/// The data is invented. Its text is for developers and for the model, so it is not in the String Catalog.
public struct EvaluationCase: Sendable, Equatable, Identifiable {
    public enum Group: String, Sendable, CaseIterable {
        case briefing = "Briefings"
        case task = "Tasks"
        case routine = "Routines"
    }

    public enum Kind: Sendable, Equatable {
        /// Word this plan. The wording must pass the same check as in the app, within the latency target.
        case briefing(BriefingRequest)
        /// Read this sentence. The name must hold the keyword and the cadence must be the expected one.
        case task(sentence: String, nameKeyword: String, cadence: Cadence?)
        /// Read this description of a week, starting from the standard routine.
        case routine(description: String, expected: RoutineExpectation)
    }

    /// The parts of a routine a description must change, or leave. Nil parts are not checked.
    public struct RoutineExpectation: Sendable, Equatable {
        public var homeDays: Set<Locale.Weekday>?
        public var officeDays: Set<Locale.Weekday>?
        public var workStart: DateComponents?
        public var workEnd: DateComponents?
        public var wakeTime: DateComponents?
        public var bedtime: DateComponents?
    }

    public var id: String
    public var languageCode: String
    public var kind: Kind

    /// A briefing passes under this, on device (spike S1).
    public static let latencyTarget = Duration.seconds(3)

    public var group: Group {
        switch kind {
        case .briefing: .briefing
        case .task: .task
        case .routine: .routine
        }
    }

    /// What the model is given, as shown on the screen.
    public var input: String {
        switch kind {
        case .briefing(let request): request.prompt()
        case .task(let sentence, _, _): sentence
        case .routine(let description, _): description
        }
    }

    var locale: Locale {
        Locale(identifier: languageCode)
    }
}

/// What the model gave for a case: its answer, how long it took, and what is wrong with it.
@MemberwiseInit(.public)
public struct EvaluationResult: Sendable, Equatable {
    public var output: String
    public var duration: Duration
    /// Empty when the case passes.
    public var problems: [String]

    public var hasPassed: Bool {
        problems.isEmpty
    }
}

extension EvaluationCase {
    /// Asks the model through the same prompts and checks as the app.
    public func run(with service: any LanguageService) async -> EvaluationResult {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            switch kind {
            case .briefing(let request):
                let text = try await service.briefing(instructions: request.instructions, plan: request.prompt())
                let duration = clock.now - start
                var problems = BriefingValidator.problems(in: text, for: request).map { "\($0)" }
                if duration > Self.latencyTarget {
                    problems.append("slower than \(Self.latencyTarget.secondsText)")
                }
                return EvaluationResult(output: text, duration: duration, problems: problems)
            case .task(let sentence, let nameKeyword, let cadence):
                let instructions = ModelInstructions.task(locale, now: Self.evaluationDay, calendar: Self.calendar)
                let draft = try await service.taskReading(instructions: instructions, sentence: sentence)
                var problems: [String] = []
                if !TaskSentenceParser.isValid(draft, for: sentence) {
                    problems.append("the app would drop this answer")
                }
                if draft.name.range(of: nameKeyword, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
                    problems.append("name has no \"\(nameKeyword)\"")
                }
                if draft.cadence != cadence {
                    problems.append("cadence is not \(cadence.map { "\($0)" } ?? "none")")
                }
                let output = "\(draft.name) · \(draft.cadence.map { "\($0)" } ?? "no cadence")"
                return EvaluationResult(output: output, duration: clock.now - start, problems: problems)
            case .routine(let description, let expected):
                let wording = RoutineWording(routine: .standard, calendar: Self.calendar, locale: locale)
                let routine = try await service.routine(instructions: wording.instructions, description: wording.prompt(for: description))
                var problems = expected.differences(from: routine)
                if !RoutineParser.isValid(routine) {
                    problems.insert("the app would drop this answer", at: 0)
                }
                return EvaluationResult(output: Self.text(routine), duration: clock.now - start, problems: problems)
            }
        } catch {
            return EvaluationResult(output: "", duration: clock.now - start, problems: ["no answer: \(error.localizedDescription)"])
        }
    }

    /// The set is fixed, so its calendar is too: Gregorian, weeks from Monday.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }()

    /// The day the task sentences are read on: Thursday 19 November 2026, 9:00 UTC.
    static let evaluationDay = Date(timeIntervalSinceReferenceDate: 816_771_600)

    private static func text(_ routine: Routine) -> String {
        func days(_ weekdays: Set<Locale.Weekday>) -> String {
            weekdays.map(\.rawValue).sorted().joined(separator: " ")
        }
        func time(_ components: DateComponents) -> String {
            String(format: "%02d:%02d", components.hour ?? -1, components.minute ?? -1)
        }
        return "home \(days(routine.homeDays)) · office \(days(routine.officeDays)) · work \(time(routine.workStart))-\(time(routine.workEnd)) · up \(time(routine.wakeTime)) · bed \(time(routine.bedtime))"
    }
}

extension EvaluationCase.RoutineExpectation {
    func differences(from routine: Routine) -> [String] {
        var differences: [String] = []
        if let homeDays, homeDays != routine.homeDays { differences.append("home days are wrong") }
        if let officeDays, officeDays != routine.officeDays { differences.append("office days are wrong") }
        if let workStart, workStart != routine.workStart { differences.append("work start is wrong") }
        if let workEnd, workEnd != routine.workEnd { differences.append("work end is wrong") }
        if let wakeTime, wakeTime != routine.wakeTime { differences.append("wake time is wrong") }
        if let bedtime, bedtime != routine.bedtime { differences.append("bedtime is wrong") }
        return differences
    }
}

extension Duration {
    /// "1.84 s", whatever the device's locale: this is developer text.
    var secondsText: String {
        String(format: "%.2f s", seconds)
    }

    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
