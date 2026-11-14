import SwiftUI
import TonyUIKit
import TonyPresentation

struct RootView: View {
    let tasksStore: Store<TasksFeature>?

    var body: some View {
        TabView {
            Tab {
                TonyColor.canvas.ignoresSafeArea()
            } label: {
                Label { Text("Today") } icon: { TonyIcon.today }
            }
            Tab {
                if let tasksStore {
                    StoreView(store: tasksStore, content: TasksScreen.init)
                } else {
                    ContentUnavailableView("Your tasks could not be opened", systemImage: "exclamationmark.triangle")
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
    }
}

/// Draws a store's data model, and draws it again whenever the store's state changes.
struct StoreView<F: Feature, Content: View>: View {
    let store: Store<F>
    let content: (F.DataModel) -> Content
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    var body: some View {
        content(store.dataModel(context: PresentationContext(now: .now, calendar: calendar, locale: locale)))
    }
}
