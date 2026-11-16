#if DEBUG
import Foundation
import FoundationModels
import TonyCore

/// Debug builds only (spike S3): tries the on-device model from wherever it is called, the widget or a background task,
/// and notes what happened in the app group for the model check screen.
enum ModelExtensionCheck {
    enum Origin: String, CaseIterable {
        case widget = "Widget"
        case backgroundTask = "Background task"
    }

    static let backgroundTaskIdentifier = "com.mt81.tony.refresh"

    static var availability: String {
        switch SystemLanguageModel.default.availability {
        case .available: "available"
        case .unavailable(.deviceNotEligible): "unavailable, this device cannot run it"
        case .unavailable(.appleIntelligenceNotEnabled): "unavailable, Apple Intelligence is off"
        case .unavailable(.modelNotReady): "unavailable, the model is not ready (still downloading?)"
        case .unavailable: "unavailable"
        }
    }

    static func run(from origin: Origin) async {
        let start = ContinuousClock.now
        let outcome: String
        do {
            let response = try await LanguageModelSession().respond(to: "Answer with one word: ready")
            let seconds = (ContinuousClock.now - start).formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 2)))
            outcome = "answered \"\(response.content.prefix(40))\" in \(seconds)"
        } catch {
            outcome = "no answer: \(error.localizedDescription)"
        }
        let time = Date.now.formatted(date: .abbreviated, time: .standard)
        defaults?.set("\(time) · model \(availability) · \(outcome)", forKey: key(origin))
    }

    static func lastResults() -> [String] {
        Origin.allCases.map { origin in
            "\(origin.rawValue): \(defaults?.string(forKey: key(origin)) ?? "has not run yet")"
        }
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: TonyCore.appGroupIdentifier)
    }

    private static func key(_ origin: Origin) -> String {
        "debug.modelCheck.\(origin.rawValue)"
    }
}
#endif
