import Foundation

/// What the on-device model is told to do, read from `Prompts/<name>.<language>.txt`. The screens and the evaluation set use the same text.
enum ModelInstructions {
    static func briefing(_ locale: Locale) -> String {
        prompt("briefing", locale)
    }

    static func task(_ locale: Locale) -> String {
        prompt("task", locale)
    }

    static func routine(_ locale: Locale) -> String {
        prompt("routine", locale)
    }

    /// The prompt in the locale's language, or in English when Tony does not speak it.
    static func prompt(_ name: String, _ locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        let url = #bundle.url(forResource: "\(name).\(language)", withExtension: "txt")
            ?? #bundle.url(forResource: "\(name).en", withExtension: "txt")
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
