import FoundationModels
import TonyCore

/// The on-device model through Foundation Models. Each briefing is one short session with typed output and no history.
struct FoundationModelsLanguageService: LanguageService {
    @Generable
    struct BriefingText {
        var text: String
    }

    enum Failure: Error {
        case modelUnavailable
    }

    func briefing(instructions: String, plan: String) async throws -> String {
        guard SystemLanguageModel.default.isAvailable else { throw Failure.modelUnavailable }
        let session = LanguageModelSession(instructions: instructions)
        return try await session.respond(to: plan, generating: BriefingText.self).content.text
    }
}
