import Foundation

/// Reads how a task repeats from a sentence, with rules, in English and French:
/// "every 5 days", "every month", "every Tuesday and Friday", "3 times a week", "tous les 5 jours", "chaque mardi", "3 fois par semaine".
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
                ("tou(?:s|tes) les " + number + " jours", { days, _ in days.map { .every($0, .day) } }),
                ("toutes les " + number + " semaines", { weeks, _ in weeks.map { .every($0, .week) } }),
                ("tous les " + number + " mois", { months, _ in months.map { .every($0, .month) } }),
                ("tous les " + number + " ans", { years, _ in years.map { .every($0, .year) } }),
                ("(?:en semaine|chaque jour de (?:la )?semaine|du lundi au vendredi)", { _, _ in .weekdays(workweek) }),
                ("(?:tous les jours|chaque jour)", { _, _ in .every(1, .day) }),
                ("(?:chaque semaine|toutes les semaines)", { _, _ in .every(1, .week) }),
                ("(?:chaque mois|tous les mois)", { _, _ in .every(1, .month) }),
                ("(?:chaque annee|tous les ans)", { _, _ in .every(1, .year) }),
                ("(?:chaque|tous les|les|le) " + day + "(?:(?:,| et|, et) (?:le |les )?" + day + ")*", { _, text in days(in: text, weekdays) }),
            ]
            : [
                (number + " times (?:a|per) week", { times, _ in times.map { .timesPerWeek($0) } }),
                ("once (?:a|per) week", { _, _ in .timesPerWeek(1) }),
                ("twice (?:a|per) week", { _, _ in .timesPerWeek(2) }),
                ("every " + number + " days", { days, _ in days.map { .every($0, .day) } }),
                ("every " + number + " weeks", { weeks, _ in weeks.map { .every($0, .week) } }),
                ("every " + number + " months", { months, _ in months.map { .every($0, .month) } }),
                ("every " + number + " years", { years, _ in years.map { .every($0, .year) } }),
                ("every other day", { _, _ in .every(2, .day) }),
                ("every other week", { _, _ in .every(2, .week) }),
                ("(?:every weekday|on weekdays|weekdays)", { _, _ in .weekdays(workweek) }),
                ("(?:every day|each day|daily)", { _, _ in .every(1, .day) }),
                ("(?:every week|each week|weekly)", { _, _ in .every(1, .week) }),
                ("(?:every month|each month|monthly)", { _, _ in .every(1, .month) }),
                ("(?:every year|each year|yearly|annually)", { _, _ in .every(1, .year) }),
                ("(?:every|each|on) " + day + "(?:(?:,| and|, and) " + day + ")*", { _, text in days(in: text, weekdays) }),
            ]

        for rule in rules {
            guard let found = find(rule.pattern), let cadence = rule.cadence(found.number, found.text), cadence.isSensible else { continue }
            let start = folded.distance(from: folded.startIndex, to: found.range.lowerBound)
            let end = folded.distance(from: folded.startIndex, to: found.range.upperBound)
            let characters = Array(sentence)
            return TaskDraft(name: name(String(characters[..<start] + characters[end...]), locale: locale), cadence: cadence)
        }
        return TaskDraft(name: name(sentence, locale: locale), cadence: nil)
    }

    private static let workweek: Set<Locale.Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    private static let englishNumbers = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7]
    private static let frenchNumbers = ["un": 1, "une": 1, "deux": 2, "trois": 3, "quatre": 4, "cinq": 5, "six": 6, "sept": 7]

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

extension Cadence {
    /// A cadence the task form can show: a count its unit offers, at least one weekday, 1 to 7 times a week.
    var isSensible: Bool {
        switch self {
        case .interval(let interval, _): (1...interval.unit.maximumCount).contains(interval.count)
        case .weekdays(let weekdays): !weekdays.isEmpty
        case .timesPerWeek(let times): (1...7).contains(times)
        }
    }
}
