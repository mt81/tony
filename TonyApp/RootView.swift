import SwiftUI
import TonyUIKit
import TonyPresentation
import TonyScreens
import TonyUIModels

struct RootView: View {
    let stores: AppStores?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @State private var selection = RootTab.today

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: RootTab.today) {
                if let stores {
                    StoreView(now: stores.now, dataModel: { TodayViewModel(store: stores.today, context: $0) }, content: TodayScreen.init)
                        .floatingButton(add)
                } else {
                    unavailable
                }
            } label: {
                Label("Today", systemImage: "sun.max")
            }
            Tab(value: RootTab.tasks) {
                if let stores {
                    StoreView(now: stores.now, dataModel: stores.tasks.dataModel, content: TasksScreen.init)
                        .floatingButton(add)
                } else {
                    unavailable
                }
            } label: {
                Label("Tasks", systemImage: "list.bullet")
            }
            Tab(value: RootTab.you) {
                if let stores {
                    StoreView(now: stores.now, dataModel: { YouViewModel(store: stores.you, context: $0) }, content: YouScreen.init)
                        .floatingButton(add)
                } else {
                    unavailable
                }
            } label: {
                Label("You", systemImage: "person")
            }
            #if DEBUG
            Tab(value: RootTab.debug) {
                DebugTab(stores: stores)
                    .floatingButton(add)
            } label: {
                Label { Text(verbatim: "Debug") } icon: { Image(systemName: "ladybug") }
            }
            #endif
        }
        .task {
            guard let stores else { return }
            await stores.today.followPlans()
        }
        .sheet(isPresented: Binding(get: { permission?.isPresented ?? false }, set: { if !$0 { permission?.dismiss.execute() } })) {
            if let stores {
                StoreView(now: stores.now, dataModel: { PermissionViewModel(store: stores.permissions, context: $0) }, content: PermissionScreen.init)
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, let stores {
                Task { await stores.today.load() }
            }
        }
    }

    /// The permission sheet, shown above every tab while the permission manager asks.
    private var permission: PermissionViewModel? {
        stores.map { PermissionViewModel(store: $0.permissions, context: PresentationContext(now: $0.now(), calendar: calendar, locale: locale)) }
    }

    /// The + beside the tabs adds a task where the user is: on Today, or on Tasks from anywhere else.
    private var add: ButtonDataModel {
        ButtonDataModel(title: String(localized: "Add a task"), systemImage: "plus", action: Action(id: "addTask") { _ in addTask() })
    }

    private func addTask() {
        guard let stores else { return }
        let now = stores.now()
        if selection == .today {
            stores.today.startAdding(id: UUID(), stepID: UUID(), now: now)
        } else {
            selection = .tasks
            stores.tasks.send(.addTapped(id: UUID(), stepID: UUID(), now: now))
        }
    }

    private var unavailable: some View {
        ContentUnavailableView("Your tasks could not be opened", systemImage: "exclamationmark.triangle")
    }
}

enum RootTab: Hashable {
    case today
    case tasks
    case you
    case debug
}

/// Draws a store's data model, and draws it again whenever the store's state changes.
struct StoreView<DataModel, Content: View>: View {
    let now: @Sendable () -> Date
    let dataModel: @MainActor (PresentationContext) -> DataModel
    let content: (DataModel) -> Content
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    var body: some View {
        content(dataModel(PresentationContext(now: now(), calendar: calendar, locale: locale)))
    }
}
