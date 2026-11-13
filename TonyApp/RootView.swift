import SwiftUI
import TonyCore
import TonyDesign

struct RootView: View {
    let repository: (any Repository)?

    var body: some View {
        TabView {
            Tab {
                TonyColor.canvas.ignoresSafeArea()
            } label: {
                Label { Text("Today") } icon: { TonyIcon.today }
            }
            Tab {
                if let repository {
                    TasksView(repository: repository)
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
