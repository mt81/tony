#if DEBUG
import SwiftUI

// Previews of the design tokens, to compare them with the Figma "Foundations" frame.

#Preview("Colours") {
    let colours: [(name: String, colour: Color)] = [
        ("canvas", TonyColor.canvas), ("sidebar", TonyColor.sidebar),
        ("surface", TonyColor.surface), ("surfaceRaised", TonyColor.surfaceRaised), ("line", TonyColor.line),
        ("ink", TonyColor.ink), ("muted", TonyColor.muted), ("accent", TonyColor.accent),
        ("accentBand", TonyColor.accentBand), ("warning", TonyColor.warning), ("warningSoft", TonyColor.warningSoft),
        ("onAccent", TonyColor.onAccent), ("glass", TonyColor.glass), ("glassEdge", TonyColor.glassEdge),
        ("glassBar", TonyColor.glassBar), ("ring", TonyColor.ring),
        ("headerViolet", TonyColor.header[0]), ("headerIndigo", TonyColor.header[1]), ("headerNavy", TonyColor.header[2]),
        ("headerNight", TonyColor.header[3]),
        ("areaYellow", TonyColor.areaYellow), ("areaGreen", TonyColor.areaGreen), ("areaBlue", TonyColor.areaBlue),
        ("areaOrange", TonyColor.areaOrange), ("areaTeal", TonyColor.areaTeal), ("areaIndigo", TonyColor.areaIndigo),
    ]
    return ScrollView {
        VStack(alignment: .leading, spacing: TonySpacing.medium) {
            ForEach(colours, id: \.name) { entry in
                HStack(spacing: TonySpacing.medium) {
                    RoundedRectangle(cornerRadius: TonyRadius.card)
                        .fill(entry.colour)
                        .frame(width: TonySize.touchTarget * 2, height: TonySize.touchTarget)
                        .overlay { RoundedRectangle(cornerRadius: TonyRadius.card).strokeBorder(TonyColor.line) }
                    Text(verbatim: entry.name).tonyText(.label).foregroundStyle(TonyColor.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .tonyPreview()
}

#Preview("Type styles") {
    ScrollView {
        VStack(alignment: .leading, spacing: TonySpacing.large) {
            ForEach(TonyTextStyle.allCases, id: \.self) { style in
                VStack(alignment: .leading, spacing: TonySpacing.hairline) {
                    Text(verbatim: String(describing: style)).tonyText(.caption).foregroundStyle(TonyColor.muted)
                    Text(verbatim: "A light day, Matteo 0123456789").tonyText(style).foregroundStyle(TonyColor.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .tonyPreview()
}

#Preview("Type styles, largest text") {
    ScrollView {
        VStack(alignment: .leading, spacing: TonySpacing.large) {
            ForEach(TonyTextStyle.allCases, id: \.self) { style in
                Text(verbatim: String(describing: style)).tonyText(style).foregroundStyle(TonyColor.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .tonyPreview()
    .dynamicTypeSize(.accessibility5)
}

#Preview("Spacing") {
    let spacings: [(name: String, value: CGFloat)] = [
        ("hairline", TonySpacing.hairline), ("textGap", TonySpacing.textGap), ("xSmall", TonySpacing.xSmall),
        ("tight", TonySpacing.tight), ("small", TonySpacing.small), ("cardVertical", TonySpacing.cardVertical),
        ("snug", TonySpacing.snug), ("medium", TonySpacing.medium), ("inset", TonySpacing.inset),
        ("large", TonySpacing.large), ("panelInset", TonySpacing.panelInset), ("page", TonySpacing.page),
        ("timeline", TonySpacing.timeline), ("section", TonySpacing.section), ("explanation", TonySpacing.explanation),
    ]
    return ScrollView {
        VStack(alignment: .leading, spacing: TonySpacing.small) {
            ForEach(spacings, id: \.name) { entry in
                HStack(spacing: TonySpacing.medium) {
                    TonyColor.accent.frame(width: entry.value, height: TonySize.checkbox)
                    Text(verbatim: "\(entry.name) · \(Int(entry.value))").tonyText(.label).foregroundStyle(TonyColor.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .tonyPreview()
}

#Preview("Radii") {
    let radii: [(name: String, value: CGFloat)] = [
        ("track", TonyRadius.track), ("card", TonyRadius.card), ("row", TonyRadius.row),
        ("stat", TonyRadius.stat), ("tile", TonyRadius.tile), ("panel", TonyRadius.panel),
    ]
    return ScrollView {
        VStack(alignment: .leading, spacing: TonySpacing.medium) {
            ForEach(radii, id: \.name) { entry in
                HStack(spacing: TonySpacing.medium) {
                    RoundedRectangle(cornerRadius: entry.value)
                        .fill(TonyColor.surface)
                        .frame(width: TonySize.touchTarget * 2, height: TonySize.touchTarget * 1.5)
                    Text(verbatim: "\(entry.name) · \(Int(entry.value))").tonyText(.label).foregroundStyle(TonyColor.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .tonyPreview()
}

#Preview("Icons and artwork") {
    VStack(alignment: .leading, spacing: TonySpacing.section) {
        HStack(spacing: TonySpacing.timeline) {
            TonyIcon.today
            TonyIcon.tasks
            TonyIcon.you
        }
        .foregroundStyle(TonyColor.ink)
        TonyImage().frame(width: TonySize.tonyHeader, height: TonySize.tonyHeader)
    }
    .tonyPreview()
}
#endif
