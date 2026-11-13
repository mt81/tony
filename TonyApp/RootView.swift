import SwiftUI
import TonyDesign

struct RootView: View {
    var body: some View {
        TabView {
            Tab {
                TonyColor.canvas.ignoresSafeArea()
            } label: {
                Label { Text("Today") } icon: { TonyIcon.today }
            }
            Tab {
                TonyColor.canvas.ignoresSafeArea()
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
