import SwiftUI
import TonyUIKit
import TonyPresentation

struct RootView: View {
    let stores: AppStores?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab {
                if let stores {
                    StoreView(store: stores.today, now: stores.now, content: TodayScreen.init)
                } else {
                    unavailable
                }
            } label: {
                Label { Text("Today") } icon: { TonyIcon.today }
            }
            Tab {
                if let stores {
                    StoreView(store: stores.tasks, now: stores.now, content: TasksScreen.init)
                } else {
                    unavailable
                }
            } label: {
                Label { Text("Tasks") } icon: { TonyIcon.tasks }
            }
            Tab {
                TonyColor.canvas.ignoresSafeArea()
            } label: {
                Label { Text("You") } icon: { TonyIcon.you }
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

    private var unavailable: some View {
        ContentUnavailableView("Your tasks could not be opened", systemImage: "exclamationmark.triangle")
    }
}

/// Draws a store's data model, and draws it again whenever the store's state changes.
struct StoreView<F: Feature, Content: View>: View {
    let store: Store<F>
    let now: @Sendable () -> Date
    let content: (F.DataModel) -> Content
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    var body: some View {
        content(store.dataModel(context: PresentationContext(now: now(), calendar: calendar, locale: locale)))
    }
}
