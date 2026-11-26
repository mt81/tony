#if DEBUG
import SwiftUI

extension View {
    /// How every preview is shown: on Tony's canvas, in the light appearance the app forces.
    /// Debug builds only. Preview text is sample data, not translated.
    public func tonyPreview(padding: CGFloat = TonySpacing.page) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(TonyColor.canvas)
            .tint(TonyColor.accentText)
            .preferredColorScheme(.light)
    }
}
#endif
