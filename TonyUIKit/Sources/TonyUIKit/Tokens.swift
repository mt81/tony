import SwiftUI

extension Bundle {
    static let design = Bundle.module
}

/// The Figma colour variables (`color/*`). The app is dark only, so each has a single value.
public enum TonyColor {
    public static let canvas = Color("Canvas", bundle: .design)
    public static let glow = Color("Glow", bundle: .design)
    public static let sidebar = Color("Sidebar", bundle: .design)
    public static let surface = Color("Surface", bundle: .design)
    public static let surfaceRaised = Color("SurfaceRaised", bundle: .design)
    public static let line = Color("Line", bundle: .design)
    public static let ink = Color("Ink", bundle: .design)
    public static let muted = Color("Muted", bundle: .design)
    public static let accent = Color("Accent", bundle: .design)
    public static let accentBand = Color("AccentBand", bundle: .design)
    public static let warning = Color("Warning", bundle: .design)
    public static let warningSoft = Color("WarningSoft", bundle: .design)
    public static let onAccent = Color("OnAccent", bundle: .design)
}

/// The spacings used in the Figma file, in points.
public enum TonySpacing {
    public static let hairline: CGFloat = 2
    public static let textGap: CGFloat = 3
    public static let xSmall: CGFloat = 4
    public static let tight: CGFloat = 6
    public static let small: CGFloat = 8
    public static let cardVertical: CGFloat = 9
    public static let snug: CGFloat = 10
    public static let medium: CGFloat = 12
    public static let inset: CGFloat = 14
    public static let large: CGFloat = 16
    public static let page: CGFloat = 20
    public static let timeline: CGFloat = 22
    public static let section: CGFloat = 28
}

public enum TonyRadius {
    public static let track: CGFloat = 5
    public static let card: CGFloat = 14
    public static let row: CGFloat = 20
    public static let stat: CGFloat = 22
    public static let tile: CGFloat = 24
}

public enum TonySize {
    /// The smallest touch target.
    public static let touchTarget: CGFloat = 44
    public static let iconCircle: CGFloat = 40
    public static let checkbox: CGFloat = 26
    public static let border: CGFloat = 1.5
    public static let rail: CGFloat = 2
    public static let nowDot: CGFloat = 14
    public static let meetingsDot: CGFloat = 10
    public static let nowMarkerHeight: CGFloat = 30
    public static let meetingsMarkerHeight: CGFloat = 34
    public static let track: CGFloat = 10
}

public enum TonyIcon {
    public static let today = Image("IconGlasses", bundle: .design)
    public static let tasks = Image("IconList", bundle: .design)
    public static let you = Image("IconFire", bundle: .design)
}

/// Tony's artwork. It is decorative, so VoiceOver skips it.
public struct TonyImage: View {
    public init() {}

    public var body: some View {
        Image("Tony", bundle: .design)
            .resizable()
            .scaledToFit()
            .foregroundStyle(TonyColor.ink)
            .accessibilityHidden(true)
    }
}
