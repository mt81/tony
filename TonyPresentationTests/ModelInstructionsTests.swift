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
        #expect(!english.contains("{language}") && !french.contains("{language}"))
    }

    @Test func theScreensReadThePromptFiles() throws {
        let french = Locale(identifier: "fr_FR")
        let task = ModelInstructions.task(french, now: try Sample.november(19), calendar: Sample.calendar)

        #expect(ModelInstructions.briefing(french) == ModelInstructions.prompt("briefing", french))
        #expect(task == ModelInstructions.prompt("task", french).replacing("{today}", with: "Thursday, November 19, 2026"))
        #expect(!task.contains("{"))
        #expect(ModelInstructions.routine(french) == ModelInstructions.prompt("routine", french))
    }

    @Test(arguments: [("en_GB", "English"), ("fr_CA", "French"), ("de_DE", "English")])
    func theLanguageIsOneTonySpeaks(identifier: String, expected: String) {
        #expect(ModelInstructions.languageName(Locale(identifier: identifier)) == expected)
    }
}
