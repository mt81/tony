import SwiftUI

/// The background of a tab: the canvas, under the bars too.
public struct PageBackground: View {
    public init() {}

    public var body: some View {
        TonyColor.canvas
            .ignoresSafeArea()
    }
}

#if DEBUG
#Preview("Page background") {
    PageBackground()
}
#endif
