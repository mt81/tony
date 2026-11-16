import SwiftUI
import TonyCore
import TonyUIKit
import TonyPresentation
import TonyStore

@main
struct TonyApp: App {
    @State private var stores = AppStores()
    #if DEBUG
    @State private var modelCheck = Store<ModelCheckFeature>(state: ModelCheckFeature.State(), environment: ModelCheckEnvironment.live)
    #endif

    var body: some Scene {
        #if DEBUG
        // Spike S3: can the model be used from a background task?
        window.backgroundTask(.appRefresh(ModelExtensionCheck.backgroundTaskIdentifier)) {
            await ModelExtensionCheck.run(from: .backgroundTask)
        }
        #else
        window
        #endif
    }

    private var window: some Scene {
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
        } else if let stores, ProcessInfo.processInfo.arguments.contains("-calendar") {
            StoreView(store: stores.calendarDebug, now: stores.now, content: CalendarDebugScreen.init)
        } else if ProcessInfo.processInfo.arguments.contains("-model") {
            StoreView(store: modelCheck, now: { Date() }, content: ModelCheckScreen.init)
        } else {
            RootView(stores: stores)
        }
        #else
        RootView(stores: stores)
        #endif
    }
}

/// Every store of the app, on one repository and one plan coordinator. Nil when the tasks cannot be opened.
@MainActor
struct AppStores {
    let now: @Sendable () -> Date
    let coordinator: PlanCoordinator
    let today: Store<TodayFeature>
    let tasks: Store<TasksFeature>
    let you: Store<YouFeature>
    #if DEBUG
    let calendarDebug: Store<CalendarDebugFeature>
    #endif

    init?() {
        guard let repository = try? SwiftDataRepository.appGroup() else { return nil }
        // Stands in for the catalogue service (D14) until it exists.
        let catalog = Bundle.main.url(forResource: "TaskCatalog", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? TableTaskCatalog(json: $0) }
        let calendarSource = EventKitCalendarSource()
        let now = Self.clock()
        let languageService = FoundationModelsLanguageService()

        self.now = now
        coordinator = PlanCoordinator(repository: repository, calendarSource: calendarSource, calendar: .current, now: now)
        today = Store(
            state: TodayFeature.State(),
            environment: TodayFeature.Environment(
                coordinator: coordinator,
                briefingWriter: BriefingWriter(service: languageService),
                repository: repository,
                catalog: catalog,
                calendar: .current,
                locale: .current
            )
        )
        tasks = Store(
            state: TasksFeature.State(),
            environment: TasksFeature.Environment(repository: repository, catalog: catalog, languageService: languageService, locale: .current)
        )
        you = Store(
            state: YouFeature.State(),
            environment: YouFeature.Environment(
                repository: repository,
                calendarSource: calendarSource,
                coordinator: coordinator,
                languageService: languageService,
                calendar: .current,
                locale: .current
            )
        )
        #if DEBUG
        calendarDebug = Store(
            state: CalendarDebugFeature.State(),
            environment: CalendarDebugFeature.Environment(calendarSource: calendarSource, coordinator: coordinator)
        )
        #endif
    }

    private static func clock() -> @Sendable () -> Date {
        #if DEBUG
        // Debug builds only: `-now 08:00` freezes the clock at that time today, to see the plan at another hour.
        let parts = (UserDefaults.standard.string(forKey: "now") ?? "").split(separator: ":").compactMap { Int($0) }
        if parts.count == 2, let frozen = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date()) {
            return { frozen }
        }
        #endif
        return { Date() }
    }
}
