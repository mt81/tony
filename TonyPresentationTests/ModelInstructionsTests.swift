import Foundation
import Testing
@testable import TonyPresentation

struct ModelInstructionsTests {
    @Test(arguments: ["briefing", "task", "routine"])
    func everyPromptNamesTheLanguageToAnswerIn(name: String) {
        let english = ModelInstructions.prompt(name, Locale(identifier: "en_US"))
        let french = ModelInstructions.prompt(name, Locale(identifier: "fr_FR"))

        #expect(english.contains("English"))
        #expect(french.contains("French"))
        #expect(!english.contains("{") && !french.contains("{"))
    }

    @Test func theScreensReadThePromptFiles() {
        let french = Locale(identifier: "fr_FR")

        #expect(ModelInstructions.briefing(french) == ModelInstructions.prompt("briefing", french))
        #expect(ModelInstructions.task(french) == ModelInstructions.prompt("task", french))
        #expect(ModelInstructions.routine(french) == ModelInstructions.prompt("routine", french))
    }

    @Test(arguments: [("en_GB", "English"), ("fr_CA", "French"), ("de_DE", "English")])
    func theLanguageIsOneTonySpeaks(identifier: String, expected: String) {
        #expect(ModelInstructions.languageName(Locale(identifier: identifier)) == expected)
    }
}
