import SwiftUI

extension Bundle {
    static let design = #bundle
}

/// The Figma colour variables (`color/*`). The app is dark only, so each has a single value.
public enum TonyColor {
    public static let canvas = Color("Canvas", bundle: .design)
    /// The header gradient at the top of a tab, from the top down to the canvas.
    public static let header = [
        Color("HeaderViolet", bundle: .design),
        Color("HeaderIndigo", bundle: .design),
        Color("HeaderNavy", bundle: .design),
        Color("HeaderNight", bundle: .design),
    ]
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
    /// The see-through fill of cards over a background.
    public static let glass = Color("Glass", bundle: .design)
    /// The edge of a glass card, and the lines between its rows.
    public static let glassEdge = Color("GlassEdge", bundle: .design)
    /// The dark round behind a task's icon.
    public static let glassBar = Color("GlassBar", bundle: .design)
    /// The outline of a timeline marker that is still to do.
    public static let ring = Color("Ring", bundle: .design)
    /// The area colours of the tiles (`color/area/*`): bed sheets, plants, home, training, supplements, sleep.
    public static let areaYellow = Color("AreaYellow", bundle: .design)
    public static let areaGreen = Color("AreaGreen", bundle: .design)
    public static let areaBlue = Color("AreaBlue", bundle: .design)
    public static let areaOrange = Color("AreaOrange", bundle: .design)
    public static let areaTeal = Color("AreaTeal", bundle: .design)
    public static let areaIndigo = Color("AreaIndigo", bundle: .design)
}

/// How much of a colour shows through where Figma draws it see-through.
public enum TonyOpacity {
    /// The fill of a tile, over its area colour.
    public static let tile = 0.5
    /// The darker fill of a tile that needs attention.
    public static let tileNeglected = 0.25
    /// The meetings on the timeline, which step back from the tasks.
    public static let meetings = 0.8
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
    public static let panelInset: CGFloat = 18
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
    public static let panel: CGFloat = 28
}

public enum TonySize {
    /// The smallest touch target.
    public static let touchTarget: CGFloat = 44
    public static let iconCircle: CGFloat = 40
    public static let checkbox: CGFloat = 26
    public static let border: CGFloat = 1.5
    /// The edge of a glass card.
    public static let glassEdge: CGFloat = 1
    /// The round behind a task's icon at the top of its form.
    public static let taskIcon: CGFloat = 72
    /// The pen on a task's icon that says it can be changed.
    public static let editBadge: CGFloat = 24
    public static let rail: CGFloat = 2
    /// The round marker of a task or of "now" on the timeline.
    public static let marker: CGFloat = 22
    /// The tick inside a done marker.
    public static let markerCheck: CGFloat = 12
    /// The gap above a task's marker, so it lines up with the task's name.
    public static let markerOffset: CGFloat = 19
    public static let meetingsDot: CGFloat = 10
    public static let nowMarkerHeight: CGFloat = 30
    public static let meetingsMarkerHeight: CGFloat = 34
    public static let track: CGFloat = 10
    public static let tonyHeader: CGFloat = 128
    /// The height of the header gradient at the top of a tab.
    public static let headerGradient: CGFloat = 860
    /// A tile's emoji.
    public static let tileIcon: CGFloat = 28
    public static let avatar: CGFloat = 60
}

public enum TonyIcon {
    public static let today = Image("IconGlasses", bundle: .design)
    public static let tasks = Image("IconList", bundle: .design)
    public static let you = Image("IconFire", bundle: .design)
}

/// Tony's artwork. It is decorative, so VoiceOver skips it.
public struct TonyImage: View {
    private let color: Color

    public init(color: Color = TonyColor.ink) {
        self.color = color
    }

    public var body: some View {
        Image("Tony", bundle: .design)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}
