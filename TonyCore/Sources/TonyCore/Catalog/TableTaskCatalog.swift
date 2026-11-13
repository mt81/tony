import Foundation

/// Stands in for the catalogue service until it exists: answers from a fixed table, in the shape the service will use.
public struct TableTaskCatalog: TaskCatalog {
    public struct Entry: Codable, Sendable, Hashable {
        /// Words that identify the task, by language code. A keyword matches at the start of a word of the task's name.
        public var keywords: [String: [String]]
        public var steps: [StepEntry]

        public init(keywords: [String: [String]], steps: [StepEntry]) {
            self.keywords = keywords
            self.steps = steps
        }
    }

    public struct StepEntry: Codable, Sendable, Hashable {
        /// The step's name, by language code.
        public var name: [String: String]
        public var mode: Step.Mode
        public var minutes: Int
        public var gapMinutes: Int

        public init(name: [String: String], mode: Step.Mode, minutes: Int, gapMinutes: Int = 0) {
            self.name = name
            self.mode = mode
            self.minutes = minutes
            self.gapMinutes = gapMinutes
        }
    }

    static let fallbackLanguage = "en"

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public init(json: Data) throws {
        entries = try JSONDecoder().decode([Entry].self, from: json)
    }

    /// The entry whose longest matching keyword is the longest; the first such entry when two tie.
    public func steps(forTaskNamed name: String, locale: Locale) -> [StepTemplate]? {
        let language = Self.language(of: locale)
        let words = " " + Self.normalised(name, locale: locale) + " "

        let matches = entries.compactMap { entry -> (entry: Entry, length: Int)? in
            let keywords = entry.keywords[language] ?? []
            let lengths = keywords
                .map { Self.normalised($0, locale: locale) }
                .filter { !$0.isEmpty && words.contains(" " + $0) }
                .map(\.count)
            return lengths.max().map { (entry, $0) }
        }
        guard
            let longest = matches.map(\.length).max(),
            let entry = matches.first(where: { $0.length == longest })?.entry
        else {
            return nil
        }

        return entry.steps.map { step in
            StepTemplate(
                name: step.name[language] ?? step.name[Self.fallbackLanguage] ?? "",
                mode: step.mode,
                duration: TimeInterval(step.minutes * 60),
                minimumGapToNextStep: TimeInterval(step.gapMinutes * 60)
            )
        }
    }

    static func language(of locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "fr": "fr"
        default: fallbackLanguage
        }
    }

    /// Lowercased, without accents, with every run of characters other than letters and digits turned into one space.
    static func normalised(_ text: String, locale: Locale) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: " ")
    }
}
