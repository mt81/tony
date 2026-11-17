import Foundation

/// Reads how a task repeats from a sentence, with rules, in English and French:
/// "every 5 days", "every Tuesday and Friday", "3 times a week", "tous les 5 jours", "chaque mardi", "3 fois par semaine".
/// What is left of the sentence is the task's name.
public enum CadenceRules {
    public static func draft(from sentence: String, locale: Locale) -> TaskDraft {
        // Matching ignores case and accents. Folding keeps one character per character, so ranges carry over.
        let folded = String(sentence.map { Character(String($0).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)) })
        let isFrench = locale.language.languageCode == .french
        let weekdays = weekdayNames(locale: locale)
        let numbers = isFrench ? frenchNumbers : englishNumbers
        let number = "(\\d+|" + numbers.keys.sorted().joined(separator: "|") + ")"
        let day = "(?:" + weekdays.keys.sorted { $0.count > $1.count }.joined(separator: "|") + ")s?"

        func value(_ text: Substring?) -> Int? {
            text.flatMap { Int($0) ?? numbers[String($0)] }
        }
        func find(_ pattern: String) -> (range: Range<String.Index>, number: Int?, text: Substring)? {
            guard let regex = try? Regex("\\b" + pattern + "\\b"), let match = folded.firstMatch(of: regex) else { return nil }
            let captured = match.output.dropFirst().compactMap { $0.substring }.first
            return (match.range, value(captured), folded[match.range])
        }

        let rules: [(pattern: String, cadence: (Int?, Substring) -> Cadence?)] =
            isFrench
            ? [
                (number + " fois par semaine", { times, _ in times.map { .timesPerWeek($0) } }),
                ("tou(?:s|tes) les " + number + " jours", { days, _ in days.map { .afterCompletion(days: $0) } }),
                ("toutes les " + number + " semaines", { weeks, _ in weeks.map { .afterCompletion(days: $0 * 7) } }),
                ("(?:tous les jours|chaque jour)", { _, _ in .afterCompletion(days: 1) }),
                ("(?:chaque semaine|toutes les semaines)", { _, _ in .afterCompletion(days: 7) }),
                ("(?:chaque mois|tous les mois)", { _, _ in .afterCompletion(days: 30) }),
                ("(?:chaque|tous les|les|le) " + day + "(?:(?:,| et|, et) (?:le |les )?" + day + ")*", { _, text in days(in: text, weekdays) }),
            ]
            : [
                (number + " times (?:a|per) week", { times, _ in times.map { .timesPerWeek($0) } }),
                ("once (?:a|per) week", { _, _ in .timesPerWeek(1) }),
                ("twice (?:a|per) week", { _, _ in .timesPerWeek(2) }),
                ("every " + number + " days", { days, _ in days.map { .afterCompletion(days: $0) } }),
                ("every " + number + " weeks", { weeks, _ in weeks.map { .afterCompletion(days: $0 * 7) } }),
                ("every other day", { _, _ in .afterCompletion(days: 2) }),
                ("(?:every day|each day|daily)", { _, _ in .afterCompletion(days: 1) }),
                ("(?:every week|each week|weekly)", { _, _ in .afterCompletion(days: 7) }),
                ("(?:every month|each month|monthly)", { _, _ in .afterCompletion(days: 30) }),
                ("(?:every|each|on) " + day + "(?:(?:,| and|, and) " + day + ")*", { _, text in days(in: text, weekdays) }),
            ]

        for rule in rules {
            guard let found = find(rule.pattern), let cadence = rule.cadence(found.number, found.text), isSensible(cadence) else { continue }
            let start = folded.distance(from: folded.startIndex, to: found.range.lowerBound)
            let end = folded.distance(from: folded.startIndex, to: found.range.upperBound)
            let characters = Array(sentence)
            return TaskDraft(name: name(String(characters[..<start] + characters[end...]), locale: locale), cadence: cadence)
        }
        return TaskDraft(name: name(sentence, locale: locale), cadence: nil)
    }

    private static let englishNumbers = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7]
    private static let frenchNumbers = ["un": 1, "une": 1, "deux": 2, "trois": 3, "quatre": 4, "cinq": 5, "six": 6, "sept": 7]

    private static func isSensible(_ cadence: Cadence) -> Bool {
        switch cadence {
        case .afterCompletion(let days): (1...365).contains(days)
        case .weekdays(let weekdays): !weekdays.isEmpty
        case .timesPerWeek(let times): (1...7).contains(times)
        }
    }

    /// The weekday names of the locale's language, lower case and without accents.
    private static func weekdayNames(locale: Locale) -> [String: Locale.Weekday] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let weekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        var names: [String: Locale.Weekday] = [:]
        for (symbol, weekday) in zip(calendar.standaloneWeekdaySymbols, weekdays) {
            names[symbol.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)] = weekday
        }
        return names
    }

    private static func days(in text: Substring, _ weekdays: [String: Locale.Weekday]) -> Cadence? {
        let found = weekdays.filter { text.contains($0.key) }.map(\.value)
        return found.isEmpty ? nil : .weekdays(Set(found))
    }

    /// The sentence without its cadence: trimmed, single spaces, first letter in upper case.
    private static func name(_ text: String, locale: Locale) -> String {
        let words = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;.:")))
        return trimmed.prefix(1).uppercased(with: locale) + trimmed.dropFirst()
    }
}
