import SwiftUI

extension Bundle {
    static let design = #bundle
}

/// The Figma colour variables (`color/*`). The app is light only, so each has a single value.
public enum TonyColor {
    public static let canvas = Color("Canvas", bundle: .design)
    public static let sidebar = Color("Sidebar", bundle: .design)
    public static let surface = Color("Surface", bundle: .design)
    public static let surfaceRaised = Color("SurfaceRaised", bundle: .design)
    public static let line = Color("Line", bundle: .design)
    public static let ink = Color("Ink", bundle: .design)
    public static let muted = Color("Muted", bundle: .design)
    public static let accent = Color("Accent", bundle: .design)
    public static let accentBand = Color("AccentBand", bundle: .design)
    /// Text and outlines in the accent: the task to do now, the selected tab.
    public static let accentText = Color("AccentText", bundle: .design)
    public static let warning = Color("Warning", bundle: .design)
    public static let warningSoft = Color("WarningSoft", bundle: .design)
    public static let onAccent = Color("OnAccent", bundle: .design)
    /// The fill of a call to action: Continue, the ✓ of a sheet, Add a task.
    public static let cta = Color("Cta", bundle: .design)
    public static let onCta = Color("OnCta", bundle: .design)
    /// The see-through white fill of rows and Tony's briefing.
    public static let glass = Color("Glass", bundle: .design)
    /// The edge of a card.
    public static let glassEdge = Color("GlassEdge", bundle: .design)
    /// The round behind the user's initial and a task's icon in its form.
    public static let glassBar = Color("GlassBar", bundle: .design)
    /// The outline of a timeline marker that is still to do, and the rail between markers.
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
    /// What is already done today, which steps back from what is next.
    public static let done = 0.5
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
    /// Between the title, illustration and text of a sheet that explains something.
    public static let explanation: CGFloat = 40
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
    /// The gap above a task's marker, so it lines up with the task's name.
    public static let markerOffset: CGFloat = 19
    public static let meetingsDot: CGFloat = 10
    public static let nowMarkerHeight: CGFloat = 30
    public static let meetingsMarkerHeight: CGFloat = 34
    public static let track: CGFloat = 10
    public static let tonyHeader: CGFloat = 128
    /// A tile's emoji.
    public static let tileIcon: CGFloat = 28
    public static let avatar: CGFloat = 60
    /// The disc behind a sheet's illustration, and the drawing on it.
    public static let illustration: CGFloat = 200
    public static let illustrationArtwork: CGFloat = 130
}

/// Tony's artwork, in its own colours. It is decorative, so VoiceOver skips it.
public struct TonyImage: View {
    public init() {}

    public var body: some View {
        Image("Tony", bundle: .design)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
