import SwiftUI
import TonyCore
import TonyStore

@main
struct TonyApp: App {
    private let repository: (any Repository)? = try? SwiftDataRepository.appGroup()

    var body: some Scene {
        WindowGroup {
            Color(.systemBackground)
                .ignoresSafeArea()
        }
    }
}
