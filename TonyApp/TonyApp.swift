import SwiftUI
import TonyCore
import TonyUIKit
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

    #if DEBUG
    /// Debug builds only: the calendar check, shown with the -calendar launch argument.
    @State private var calendarDebugStore: Store<CalendarDebugFeature>? = {
        guard
            ProcessInfo.processInfo.arguments.contains("-calendar"),
            let repository = try? SwiftDataRepository.appGroup()
        else {
            return nil
        }
        let calendarSource = EventKitCalendarSource()
        let coordinator = PlanCoordinator(repository: repository, calendarSource: calendarSource, calendar: .current) { Date() }
        let environment = CalendarDebugFeature.Environment(calendarSource: calendarSource, coordinator: coordinator)
        return Store(state: CalendarDebugFeature.State(), environment: environment)
    }()
    #endif

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
        } else if let calendarDebugStore {
            StoreView(store: calendarDebugStore, content: CalendarDebugScreen.init)
        } else {
            RootView(tasksStore: tasksStore)
        }
        #else
        RootView(tasksStore: tasksStore)
        #endif
    }
}
