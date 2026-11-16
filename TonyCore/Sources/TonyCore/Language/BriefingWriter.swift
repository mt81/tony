import Foundation

/// A briefing and where its words come from.
public struct Briefing: Sendable, Hashable {
    public enum Source: Sendable, Hashable {
        case model
        case template
    }

    public var text: String
    public var source: Source

    public init(text: String, source: Source) {
        self.text = text
        self.source = source
    }
}

/// Words the day's briefing with the language service: one try, one retry, then the template.
/// A wording is kept for as long as the plan it words does not change.
public actor BriefingWriter {
    private let service: (any LanguageService)?
    private var cache: [BriefingRequest: Briefing] = [:]

    /// Without a service every briefing is the template.
    public init(service: (any LanguageService)?) {
        self.service = service
    }

    public func briefing(for request: BriefingRequest) async -> Briefing {
        if let cached = cache[request] {
            return cached
        }
        let template = Briefing(text: request.fallback, source: .template)
        guard let service else { return template }

        var hasAnswered = false
        for _ in 0..<2 {
            guard let text = try? await service.briefing(instructions: request.instructions, plan: request.prompt()) else { continue }
            hasAnswered = true
            if BriefingValidator.problems(in: text, for: request).isEmpty {
                let briefing = Briefing(text: text.trimmingCharacters(in: .whitespacesAndNewlines), source: .model)
                cache[request] = briefing
                return briefing
            }
        }
        // A model that answered twice with something invalid is not asked again for this plan.
        // One that could not answer (not downloaded yet, busy) is asked again next time.
        if hasAnswered {
            cache[request] = template
        }
        return template
    }
}
