import SwiftUI
import TonyUIModels

/// Where calendar access stands, with the button that asks for it.
public struct CalendarCard: View {
    private let model: CalendarCardDataModel

    public init(_ model: CalendarCardDataModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TonySpacing.small) {
            Text(model.title)
                .tonyText(.heading)
                .foregroundStyle(TonyColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text(model.text)
                .tonyText(.body)
                .foregroundStyle(TonyColor.ink)
                .accessibilityIdentifier(ifPresent: model.textAccessibilityIdentifier)
            if let allow = model.allow {
                Button {
                    allow.action.execute()
                } label: {
                    // Not a chip: a chip stays on one line, and this title must wrap at large text sizes.
                    Text(allow.title)
                        .tonyText(.labelSmall)
                        .foregroundStyle(TonyColor.onAccent)
                        .padding(.horizontal, TonySpacing.inset)
                        .padding(.vertical, TonySpacing.small)
                        .background(TonyColor.accent, in: .rect(cornerRadius: TonyRadius.row))
                        .frame(minHeight: TonySize.touchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(ifPresent: allow.accessibilityIdentifier)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TonySpacing.panelInset)
        .glassCard(cornerRadius: TonyRadius.tile)
    }
}

#if DEBUG
#Preview("Calendar card") {
    CalendarCard(
        CalendarCardDataModel(
            title: "Calendar",
            text: "Tony doesn't see your calendar yet, so he can't plan around your meetings.",
            allow: ButtonDataModel(title: "Plan around my events", action: Action(id: "preview") { _ in })
        )
    )
    .tonyPreview()
}

#Preview("Calendar card, largest text") {
    CalendarCard(
        CalendarCardDataModel(
            title: "Calendar",
            text: "Tony doesn't see your calendar yet, so he can't plan around your meetings.",
            allow: ButtonDataModel(title: "Plan around my events", action: Action(id: "preview") { _ in })
        )
    )
    .tonyPreview()
    .dynamicTypeSize(.accessibility5)
}
#endif
