import SwiftUI

/// The background of a tab: Tony's glow at the top, fading into the canvas.
public struct PageBackground: View {
    public init() {}

    public var body: some View {
        LinearGradient(
            stops: [.init(color: TonyColor.glow, location: 0), .init(color: TonyColor.canvas, location: 0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#if DEBUG
#Preview("Page background") {
    PageBackground()
        .preferredColorScheme(.dark)
}
#endif
