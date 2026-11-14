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
                    .foregroundStyle(TonyColor.muted)
                    .accessibilityHidden(true)
                IconCircle(icon: model.icon, isNeglected: model.isNeglected)
            }
            VStack(alignment: .leading, spacing: TonySpacing.hairline) {
                if dynamicTypeSize.isAccessibilitySize {
                    IconCircle(icon: model.icon, isNeglected: model.isNeglected)
                }
                Text(model.title).tonyText(.labelLarge).foregroundStyle(TonyColor.ink)
                Text(model.subtitle).tonyText(.caption).foregroundStyle(TonyColor.muted)
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
        .background(TonyColor.surface, in: .rect(cornerRadius: TonyRadius.row))
        .accessibilityElement(children: .combine)
    }
}

/// A "How things are" tile: an area or a task with its mood.
public struct Tile: View {
    private let model: TileDataModel

    public init(_ model: TileDataModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TonySpacing.tight) {
            Text(model.icon)
                .tonyText(.numeral)
                .accessibilityHidden(true)
                .padding(.bottom, TonySpacing.xSmall)
            Text(model.title).tonyText(.labelLarge).foregroundStyle(TonyColor.ink)
            Text(model.detail).tonyText(.caption).foregroundStyle(model.isNeglected ? TonyColor.warning : TonyColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TonySpacing.large)
        .background(model.isNeglected ? TonyColor.warningSoft : TonyColor.surface, in: .rect(cornerRadius: TonyRadius.tile))
        .accessibilityElement(children: .combine)
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
            Text(model.label).tonyText(.caption).foregroundStyle(TonyColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TonySpacing.large)
        .background(TonyColor.surface, in: .rect(cornerRadius: TonyRadius.stat))
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
            Text(model.status).tonyText(.caption).foregroundStyle(TonyColor.muted)
        }
        .accessibilityElement(children: .combine)
    }
}
