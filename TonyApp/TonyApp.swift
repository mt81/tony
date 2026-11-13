import SwiftUI
import TonyCore
import TonyDesign
import TonyStore

@main
struct TonyApp: App {
    private let repository: (any Repository)? = try? SwiftDataRepository.appGroup()
    /// Stands in for the catalogue service (D14) until it exists.
    private let catalog: (any TaskCatalog)? = Bundle.main.url(forResource: "TaskCatalog", withExtension: "json")
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { try? TableTaskCatalog(json: $0) }

    var body: some Scene {
        WindowGroup {
            content
                .tint(TonyColor.accent)
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder private var content: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-gallery") {
            ComponentGallery()
        } else {
            RootView(repository: repository, catalog: catalog)
        }
        #else
        RootView(repository: repository, catalog: catalog)
        #endif
    }
}
