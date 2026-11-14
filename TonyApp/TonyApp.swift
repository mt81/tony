import SwiftUI
import TonyCore
import TonyDesign
import TonyPresentation
import TonyStore

@main
struct TonyApp: App {
    @State private var tasksStore: Store<TasksFeature>? = {
        guard let repository = try? SwiftDataRepository.appGroup() else { return nil }
        // Stands in for the catalogue service (D14) until it exists.
        let catalog = Bundle.main.url(forResource: "TaskCatalog", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? TableTaskCatalog(json: $0) }
        let environment = TasksFeature.Environment(repository: repository, catalog: catalog, locale: .current)
        return Store(state: TasksFeature.State(), environment: environment)
    }()

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
            RootView(tasksStore: tasksStore)
        }
        #else
        RootView(tasksStore: tasksStore)
        #endif
    }
}
