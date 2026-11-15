import SwiftUI

/// The background of a tab: Tony's glow at the top, fading into the canvas.
struct PageBackground: View {
    var body: some View {
        LinearGradient(
            stops: [.init(color: TonyColor.glow, location: 0), .init(color: TonyColor.canvas, location: 0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
