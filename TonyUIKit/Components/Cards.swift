import SwiftUI
import TonyUIModels

/// A task in the Tasks tab: icon, name, cadence line and a status chip.
public struct TaskRow: View {
    private let model: TaskRowDataModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(_ model: TaskRowDataModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: TonySpacing.medium) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "line.3.horizontal")
                    .tonyText(.labelLarge)
                    .foregroundStyle(TonyColor.ink)
                    .accessibilityHidden(true)
                IconCircle(icon: model.icon, isNeglected: model.isNeglected)
            }
            VStack(alignment: .leading, spacing: TonySpacing.hairline) {
                if dynamicTypeSize.isAccessibilitySize {
                    IconCircle(icon: model.icon, isNeglected: model.isNeglected)
                }
                Text(model.title).tonyText(.labelLarge).foregroundStyle(TonyColor.ink)
                Text(model.subtitle).tonyText(.caption).foregroundStyle(TonyColor.ink)
                if dynamicTypeSize.isAccessibilitySize {
                    Chip(model.status).padding(.top, TonySpacing.tight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !dynamicTypeSize.isAccessibilitySize {
                Chip(model.status)
            }
        }
        .padding(.horizontal, TonySpacing.inset)
        .padding(.vertical, TonySpacing.medium)
        .glassCard(cornerRadius: TonyRadius.row)
        .accessibilityElement(children: .combine)
    }
}

/// A "How things are" tile: a task with its mood, on its area colour.
public struct Tile: View {
    private let model: TileDataModel
    @ScaledMetric(relativeTo: .title) private var iconSize = TonySize.tileIcon

    public init(_ model: TileDataModel) {
        self.model = model
    }

    public var body: some View {
        let colour = Self.colour(model.colour)
        VStack(alignment: .leading, spacing: TonySpacing.tight) {
            Text(model.icon)
                .font(.system(size: iconSize))
                .accessibilityHidden(true)
                .padding(.bottom, TonySpacing.xSmall)
            Text(model.title).tonyText(.labelLarge).foregroundStyle(TonyColor.ink)
            Text(model.detail).tonyText(.caption).foregroundStyle(model.isNeglected ? TonyColor.warning : TonyColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TonySpacing.large)
        .background(colour.opacity(model.isNeglected ? TonyOpacity.tileNeglected : TonyOpacity.tile), in: .rect(cornerRadius: TonyRadius.tile))
        .overlay {
            RoundedRectangle(cornerRadius: TonyRadius.tile)
                .strokeBorder(colour, lineWidth: TonySize.glassEdge)
        }
        .accessibilityElement(children: .combine)
    }

    private static func colour(_ colour: TileDataModel.Colour) -> Color {
        switch colour {
        case .yellow: TonyColor.areaYellow
        case .green: TonyColor.areaGreen
        case .blue: TonyColor.areaBlue
        case .orange: TonyColor.areaOrange
        case .teal: TonyColor.areaTeal
        case .indigo: TonyColor.areaIndigo
        }
    }
}

/// One number with its caption.
public struct Stat: View {
    private let model: StatDataModel

    public init(_ model: StatDataModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TonySpacing.xSmall) {
            Text(model.value).tonyText(.numeral).foregroundStyle(TonyColor.ink)
            Text(model.label).tonyText(.caption).foregroundStyle(TonyColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TonySpacing.large)
        .glassCard(cornerRadius: TonyRadius.stat)
        .accessibilityElement(children: .combine)
    }
}

/// Progress of one area (Home, Plants, Training), with its state in words.
public struct AreaRow: View {
    private let model: AreaRowDataModel

    public init(_ model: AreaRowDataModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: TonySpacing.snug) {
            Text(model.name).tonyText(.label).foregroundStyle(TonyColor.ink)
            TonyColor.line
                .frame(height: TonySize.track)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        TonyColor.accent
                            .clipShape(.rect(cornerRadius: TonyRadius.track))
                            .frame(width: proxy.size.width * min(max(model.progress, 0), 1))
                    }
                }
                .clipShape(.rect(cornerRadius: TonyRadius.track))
                .accessibilityHidden(true)
            Text(model.status).tonyText(.caption).foregroundStyle(TonyColor.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// The see-through card of the tabs: the glass fill with its edge.
    public func glassCard(cornerRadius: CGFloat) -> some View {
        background(TonyColor.glass, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(TonyColor.glassEdge, lineWidth: TonySize.glassEdge)
            }
    }
}

#if DEBUG
#Preview("Task row") {
    VStack(spacing: TonySpacing.small) {
        TaskRow(ComponentGallery.row(icon: "🧺", title: "Laundry", subtitle: "Every week · wash, dry, fold", status: ChipDataModel(title: "Today")))
        TaskRow(
            ComponentGallery.row(
                icon: "🥀",
                title: "Water the plants",
                subtitle: "Every 5 days after last time",
                status: ChipDataModel(title: "Due", style: .warning),
                isNeglected: true
            )
        )
    }
    .tonyPreview()
}

#Preview("Task row, largest text") {
    TaskRow(
        ComponentGallery.row(
            icon: "🥀",
            title: "Water the plants",
            subtitle: "Every 5 days after last time",
            status: ChipDataModel(title: "Due", style: .warning),
            isNeglected: true
        )
    )
    .tonyPreview()
    .dynamicTypeSize(.accessibility5)
}

#Preview("Tiles") {
    LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: TonySpacing.medium) {
        Tile(TileDataModel(icon: "🛏️", title: "Bed sheets", detail: "16 days since last time", colour: .yellow, isNeglected: true))
        Tile(TileDataModel(icon: "🪴", title: "Plants", detail: "5 days since last time", colour: .green, isNeglected: true))
        Tile(TileDataModel(icon: "🏠", title: "Home", detail: "In 3 days", colour: .blue))
        Tile(TileDataModel(icon: "🏋️", title: "Training", detail: "2 of 4 this week", colour: .orange))
        Tile(TileDataModel(icon: "💊", title: "Supplements", detail: "Done today", colour: .teal))
        Tile(TileDataModel(icon: "😴", title: "Sleep", detail: "Every day", colour: .indigo))
    }
    .tonyPreview()
}

#Preview("Stat") {
    HStack(alignment: .top, spacing: TonySpacing.medium) {
        Stat(StatDataModel(value: "12", label: "tasks done"))
        Stat(StatDataModel(value: "2/4", label: "gym sessions"))
    }
    .tonyPreview()
}

#Preview("Area row") {
    VStack(spacing: TonySpacing.medium) {
        AreaRow(AreaRowDataModel(name: "Home", progress: 0.6, status: "Good"))
        AreaRow(AreaRowDataModel(name: "Plants", progress: 0.2, status: "Thirsty"))
    }
    .tonyPreview()
}
#endif
