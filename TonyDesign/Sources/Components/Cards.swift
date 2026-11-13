import SwiftUI

/// A task in the Tasks tab: icon, name, cadence line and a status chip.
public struct TaskRow: View {
    private let icon: String
    private let title: String
    private let subtitle: String
    private let status: String
    private let isNeglected: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(icon: String, title: String, subtitle: String, status: String, isNeglected: Bool = false) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.isNeglected = isNeglected
    }

    public var body: some View {
        HStack(spacing: TonySpacing.medium) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "line.3.horizontal")
                    .tonyText(.labelLarge)
                    .foregroundStyle(TonyColor.muted)
                    .accessibilityHidden(true)
                IconCircle(icon: icon, isNeglected: isNeglected)
            }
            VStack(alignment: .leading, spacing: TonySpacing.hairline) {
                if dynamicTypeSize.isAccessibilitySize {
                    IconCircle(icon: icon, isNeglected: isNeglected)
                }
                Text(title).tonyText(.labelLarge).foregroundStyle(TonyColor.ink)
                Text(subtitle).tonyText(.caption).foregroundStyle(TonyColor.muted)
                if dynamicTypeSize.isAccessibilitySize {
                    statusChip.padding(.top, TonySpacing.tight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !dynamicTypeSize.isAccessibilitySize {
                statusChip
            }
        }
        .padding(.horizontal, TonySpacing.inset)
        .padding(.vertical, TonySpacing.medium)
        .background(TonyColor.surface, in: .rect(cornerRadius: TonyRadius.row))
        .accessibilityElement(children: .combine)
    }
}

extension TaskRow {
    private var statusChip: some View {
        Chip(status, style: isNeglected ? .warning : .neutral)
    }
}

/// A "How things are" tile: an area or a task with its mood.
public struct Tile: View {
    private let icon: String
    private let title: String
    private let detail: String
    private let isNeglected: Bool

    public init(icon: String, title: String, detail: String, isNeglected: Bool = false) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.isNeglected = isNeglected
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TonySpacing.tight) {
            Text(icon)
                .tonyText(.numeral)
                .accessibilityHidden(true)
                .padding(.bottom, TonySpacing.xSmall)
            Text(title).tonyText(.labelLarge).foregroundStyle(TonyColor.ink)
            Text(detail).tonyText(.caption).foregroundStyle(isNeglected ? TonyColor.warning : TonyColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TonySpacing.large)
        .background(isNeglected ? TonyColor.warningSoft : TonyColor.surface, in: .rect(cornerRadius: TonyRadius.tile))
        .accessibilityElement(children: .combine)
    }
}

/// One number with its caption.
public struct Stat: View {
    private let value: String
    private let label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TonySpacing.xSmall) {
            Text(value).tonyText(.numeral).foregroundStyle(TonyColor.ink)
            Text(label).tonyText(.caption).foregroundStyle(TonyColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TonySpacing.large)
        .background(TonyColor.surface, in: .rect(cornerRadius: TonyRadius.stat))
        .accessibilityElement(children: .combine)
    }
}

/// Progress of one area (Home, Plants, Training), with its state in words.
public struct AreaRow: View {
    private let name: String
    private let progress: Double
    private let status: String

    public init(name: String, progress: Double, status: String) {
        self.name = name
        self.progress = progress
        self.status = status
    }

    public var body: some View {
        HStack(spacing: TonySpacing.snug) {
            Text(name).tonyText(.label).foregroundStyle(TonyColor.ink)
            TonyColor.line
                .frame(height: TonySize.track)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        TonyColor.accent
                            .clipShape(.rect(cornerRadius: TonyRadius.track))
                            .frame(width: proxy.size.width * min(max(progress, 0), 1))
                    }
                }
                .clipShape(.rect(cornerRadius: TonyRadius.track))
                .accessibilityHidden(true)
            Text(status).tonyText(.caption).foregroundStyle(TonyColor.muted)
        }
        .accessibilityElement(children: .combine)
    }
}
