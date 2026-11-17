import Foundation

/// Words the day's briefing with the language service: one try, one retry, then nil so that the caller shows its template.
/// A wording is kept for as long as the plan it words does not change.
public actor BriefingWriter {
    private let service: (any LanguageService)?
    private var cache: [BriefingRequest: String?] = [:]

    /// Without a service there is never a wording.
    public init(service: (any LanguageService)?) {
        self.service = service
    }

    /// The model's wording of the plan, or nil when it gave no valid one.
    public func briefing(for request: BriefingRequest) async -> String? {
        if let cached = cache[request] {
            return cached
        }
        guard let service else { return nil }

        var hasAnswered = false
        for _ in 0..<2 {
            guard let text = try? await service.briefing(instructions: request.instructions, plan: request.prompt()) else { continue }
            hasAnswered = true
            if BriefingValidator.problems(in: text, for: request).isEmpty {
                let briefing = text.trimmingCharacters(in: .whitespacesAndNewlines)
                cache[request] = briefing
                return briefing
            }
        }
        // A model that answered twice with something invalid is not asked again for this plan.
        // One that could not answer (not downloaded yet, busy) is asked again next time.
        if hasAnswered {
            cache.updateValue(nil, forKey: request)
        }
        return nil
    }
}
