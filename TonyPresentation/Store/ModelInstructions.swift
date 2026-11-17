import Foundation

/// What the on-device model is told to do, read from `Prompts/<name>.txt`. The screens and the evaluation set use the same text.
/// The prompts are in English and name the language to answer in.
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

    static func prompt(_ name: String, _ locale: Locale) -> String {
        guard let url = #bundle.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing("{language}", with: languageName(locale))
    }

    /// The language Tony speaks closest to the locale's, named in English: "French". A language Tony does not speak gives English.
    static func languageName(_ locale: Locale) -> String {
        let code = Bundle.preferredLocalizations(from: #bundle.localizations, forPreferences: [locale.identifier]).first ?? "en"
        return Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
    }
}
