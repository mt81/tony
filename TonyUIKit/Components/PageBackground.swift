import SwiftUI

/// The background of a tab: the violet header gradient at the top, fading into the canvas.
public struct PageBackground: View {
    public init() {}

    public var body: some View {
        let colours = TonyColor.header + [TonyColor.canvas]
        let locations = [0, 0.3, 0.62, 0.85, 1]
        LinearGradient(
            stops: zip(colours, locations).map { Gradient.Stop(color: $0, location: $1) },
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: TonySize.headerGradient)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(TonyColor.canvas)
        .ignoresSafeArea()
    }
}

#if DEBUG
#Preview("Page background") {
    PageBackground()
        .preferredColorScheme(.dark)
}
#endif
