#if DEBUG
import BackgroundTasks
import Foundation
import TonyPresentation
import UIKit

/// Debug builds only: what the model check screen needs from the system.
enum ModelCheckEnvironment {
    static var live: ModelCheckFeature.Environment {
        ModelCheckFeature.Environment(
            languageService: FoundationModelsLanguageService(),
            availability: { ModelExtensionCheck.availability },
            system: {
                let version = ProcessInfo.processInfo.operatingSystemVersionString
                return await "\(UIDevice.current.systemName) \(version) · \(UIDevice.current.model)"
            },
            extensionChecks: { ModelExtensionCheck.lastResults() },
            requestBackgroundCheck: {
                do {
                    try await BGTaskScheduler.shared.submitTaskRequest(BGAppRefreshTaskRequest(identifier: ModelExtensionCheck.backgroundTaskIdentifier))
                    return "Requested. iOS decides when it runs; come back to this screen later."
                } catch {
                    return "iOS refused the request: \(error.localizedDescription)"
                }
            }
        )
    }
}
#endif
