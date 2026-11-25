import SwiftUI
import TonyUIModels

/// A sheet's illustration, on a soft disc.
public struct IllustrationView: View {
    private let illustration: Illustration

    public init(_ illustration: Illustration) {
        self.illustration = illustration
    }

    public var body: some View {
        artwork
            .frame(width: TonySize.illustrationArtwork, height: TonySize.illustrationArtwork)
            .frame(width: TonySize.illustration, height: TonySize.illustration)
            .background(TonyColor.surfaceRaised, in: .circle)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        switch illustration {
        case .tony: TonyImage()
        }
    }
}

#if DEBUG
#Preview("Illustration") {
    IllustrationView(.tony)
        .tonyPreview()
}
#endif
