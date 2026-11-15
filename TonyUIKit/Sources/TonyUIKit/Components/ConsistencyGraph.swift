import SwiftUI
import TonyUIModels

/// One week of consistency: a band, the line of the days so far, and a dot per day.
public struct ConsistencyGraph: View {
    private let model: ConsistencyDataModel

    public init(_ model: ConsistencyDataModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: TonySpacing.small) {
                    title
                    Spacer()
                    caption
                }
                VStack(alignment: .leading, spacing: TonySpacing.xSmall) {
                    title
                    caption
                }
            }
            .padding(.top, TonySpacing.large)
            .padding(.horizontal, TonySpacing.panelInset)

            GeometryReader { proxy in
                path(in: proxy.size)
            }
            .frame(height: TonySize.graphHeight)

            HStack(alignment: .top, spacing: 0) {
                ForEach(model.days) { day in
                    VStack(spacing: TonySpacing.xSmall) {
                        Text(day.letter).tonyText(.labelSmall)
                        Text(day.value).tonyText(.caption)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(day.isToday ? TonyColor.ink : TonyColor.muted)
                    .frame(maxWidth: .infinity)
                }
            }
            // Seven columns cannot grow with the text; VoiceOver reads the week from the label instead.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            Text(model.footnote)
                .tonyText(.bodySmall)
                .foregroundStyle(TonyColor.muted)
                .padding(.top, TonySpacing.medium)
                .padding(.horizontal, TonySpacing.panelInset)
        }
        .padding(.bottom, TonySpacing.large)
        .background(TonyColor.surface, in: .rect(cornerRadius: TonyRadius.panel))
        .clipShape(.rect(cornerRadius: TonyRadius.panel))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.accessibilityLabel)
        .accessibilityHint(model.footnote)
    }

    private var title: some View {
        Text(model.title).tonyText(.labelStrong).foregroundStyle(TonyColor.ink).fixedSize()
    }

    private var caption: some View {
        Text(model.caption).tonyText(.caption).foregroundStyle(TonyColor.muted).fixedSize()
    }

    private func path(in size: CGSize) -> some View {
        let columnWidth = size.width / CGFloat(max(model.days.count, 1))
        let points = model.days.indices.map { index in
            CGPoint(
                x: (CGFloat(index) + 0.5) * columnWidth,
                y: TonySize.graphBand + (1 - min(max(model.days[index].level, 0), 1)) * (size.height - 2 * TonySize.graphBand)
            )
        }
        let reached = zip(model.days, points).filter { $0.0.kind != .upcoming }.map(\.1)
        let edges = [points.first.map { CGPoint(x: -columnWidth, y: $0.y) }, points.last.map { CGPoint(x: size.width + columnWidth, y: $0.y) }]

        return ZStack {
            Self.curve(through: [edges[0]].compactMap(\.self) + points + [edges[1]].compactMap(\.self))
                .stroke(TonyColor.accentBand, lineWidth: TonySize.graphBand)
            Self.curve(through: reached)
                .stroke(TonyColor.accent, lineWidth: TonySize.rail)
            ForEach(model.days) { day in
                Circle()
                    .fill(day.kind == .scored ? TonyColor.accent : TonyColor.muted)
                    .frame(width: diameter(of: day), height: diameter(of: day))
                    .position(points[day.id])
            }
        }
    }

    private func diameter(of day: ConsistencyDataModel.Day) -> CGFloat {
        if day.isToday {
            return TonySize.graphTodayDot
        }
        return day.kind == .scored ? TonySize.graphScoreDot : TonySize.graphDot
    }

    private static func curve(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for (previous, point) in zip(points, points.dropFirst()) {
            let middle = (previous.x + point.x) / 2
            path.addCurve(to: point, control1: CGPoint(x: middle, y: previous.y), control2: CGPoint(x: middle, y: point.y))
        }
        return path
    }
}
