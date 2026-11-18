import SwiftUI
import TonyUIKit
import TonyPresentation
import TonyScreens

struct RootView: View {
    let stores: AppStores?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab {
                if let stores {
                    StoreView(now: stores.now, dataModel: stores.today.dataModel, content: TodayScreen.init)
                } else {
                    unavailable
                }
            } label: {
                Label { Text("Today") } icon: { TonyIcon.today }
            }
            Tab {
                if let stores {
                    StoreView(now: stores.now, dataModel: stores.tasks.dataModel, content: TasksScreen.init)
                } else {
                    unavailable
                }
            } label: {
                Label { Text("Tasks") } icon: { TonyIcon.tasks }
            }
            Tab {
                if let stores {
                    StoreView(now: stores.now, dataModel: { YouViewModel(store: stores.you, context: $0) }, content: YouScreen.init)
                } else {
                    unavailable
                }
            } label: {
                Label { Text("You") } icon: { TonyIcon.you }
            }
            #if DEBUG
            Tab {
                DebugTab(stores: stores)
            } label: {
                Label { Text(verbatim: "Debug") } icon: { Image(systemName: "ladybug") }
            }
            #endif
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

    private var unavailable: some View {
        ContentUnavailableView("Your tasks could not be opened", systemImage: "exclamationmark.triangle")
    }
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
