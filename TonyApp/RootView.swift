import SwiftUI
import TonyUIKit
import TonyPresentation
import TonyScreens

struct RootView: View {
    let stores: AppStores?
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = RootTab.today

    var body: some View {
        TabView(selection: Binding(get: { selection }, set: select)) {
            Tab(value: RootTab.today) {
                if let stores {
                    StoreView(now: stores.now, dataModel: stores.today.dataModel, content: TodayScreen.init)
                } else {
                    unavailable
                }
            } label: {
                Label { Text("Today") } icon: { TonyIcon.today }
            }
            Tab(value: RootTab.tasks) {
                if let stores {
                    StoreView(now: stores.now, dataModel: stores.tasks.dataModel, content: TasksScreen.init)
                } else {
                    unavailable
                }
            } label: {
                Label { Text("Tasks") } icon: { TonyIcon.tasks }
            }
            Tab(value: RootTab.you) {
                if let stores {
                    StoreView(now: stores.now, dataModel: { YouViewModel(store: stores.you, context: $0) }, content: YouScreen.init)
                } else {
                    unavailable
                }
            } label: {
                Label { Text("You") } icon: { TonyIcon.you }
            }
            #if DEBUG
            Tab(value: RootTab.debug) {
                DebugTab(stores: stores)
            } label: {
                Label { Text(verbatim: "Debug") } icon: { Image(systemName: "ladybug") }
            }
            #endif
            // The + is a tab only to sit in the tab bar: selecting it adds a task and goes back.
            Tab(value: RootTab.add, role: .search) {
                EmptyView()
            } label: {
                Label("Add a task", systemImage: "plus")
            }
        }
        .task {
            guard let stores else { return }
            for await planned in await stores.coordinator.plans() {
                stores.today.send(.planned(planned))
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                stores?.today.send(.appeared)
            }
        }
    }

    /// The + adds a task where the user is: on Today, or on Tasks from anywhere else.
    /// The tab bar shows the + tab as soon as it is tapped, so the selection goes there and comes straight back.
    private func select(_ tab: RootTab) {
        guard tab == .add else {
            selection = tab
            return
        }
        guard let stores else { return }
        let destination = selection == .today ? RootTab.today : RootTab.tasks
        selection = .add
        Task { @MainActor in
            selection = destination
            let now = stores.now()
            if destination == .today {
                stores.today.send(.addTapped(id: UUID(), stepID: UUID(), now: now))
            } else {
                stores.tasks.send(.addTapped(id: UUID(), stepID: UUID(), now: now))
            }
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
    case add
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
