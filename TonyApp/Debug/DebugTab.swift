#if DEBUG
import SwiftUI
import TonyPresentation
import TonyScreens
import TonyUIKit

/// Debug builds only: the developer screens, in their own tab. Their text is for developers, so it is in English and not translated.
struct DebugTab: View {
    let stores: AppStores?
    @State private var modelCheck = Store<ModelCheckFeature>(state: ModelCheckFeature.State(), environment: ModelCheckEnvironment.live)

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    StoreView(store: modelCheck, now: { Date() }, content: ModelCheckScreen.init)
                } label: {
                    Text(verbatim: "Model check")
                }
                if let stores {
                    NavigationLink {
                        StoreView(store: stores.calendarDebug, now: stores.now, content: CalendarDebugScreen.init)
                    } label: {
                        Text(verbatim: "Calendar check")
                    }
                }
                NavigationLink {
                    ComponentGallery()
                } label: {
                    Text(verbatim: "Component gallery")
                }
            }
            .scrollContentBackground(.hidden)
            .background(TonyColor.canvas)
            .navigationTitle(Text(verbatim: "Debug"))
        }
    }
}
#endif
