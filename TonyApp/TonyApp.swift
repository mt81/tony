import SwiftUI
import TonyCore
import TonyDesign
import TonyStore

@main
struct TonyApp: App {
    private let repository: (any Repository)? = try? SwiftDataRepository.appGroup()

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
            RootView(repository: repository)
        }
        #else
        RootView(repository: repository)
        #endif
    }
}
