import Foundation
import Testing
@testable import TonyPresentation

struct ModelInstructionsTests {
    @Test(arguments: ["briefing", "task", "routine"])
    func everyPromptIsWrittenInEnglishAndInFrench(name: String) {
        let english = ModelInstructions.prompt(name, Locale(identifier: "en_US"))
        let french = ModelInstructions.prompt(name, Locale(identifier: "fr_FR"))

        #expect(!english.isEmpty)
        #expect(!french.isEmpty)
        #expect(english != french)
    }

    @Test func theScreensReadThePromptFiles() {
        let french = Locale(identifier: "fr_FR")

        #expect(ModelInstructions.briefing(french) == ModelInstructions.prompt("briefing", french))
        #expect(ModelInstructions.task(french) == ModelInstructions.prompt("task", french))
        #expect(ModelInstructions.routine(french) == ModelInstructions.prompt("routine", french))
    }

    @Test func aLanguageTonyDoesNotSpeakGetsTheEnglishPrompt() {
        #expect(ModelInstructions.prompt("briefing", Locale(identifier: "de_DE")) == ModelInstructions.prompt("briefing", Locale(identifier: "en_US")))
    }
}
