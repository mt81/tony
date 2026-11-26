import SwiftUI
import TonyUIModels

/// The action that creates something, on black glass, floating at the bottom of a tab: never in the tab bar.
public struct FloatingButton: View {
    private let model: ButtonDataModel
    @ScaledMetric(relativeTo: .title2) private var diameter = TonySize.floatingButton

    public init(_ model: ButtonDataModel) {
        self.model = model
    }

    public var body: some View {
        Button {
            model.action.execute()
        } label: {
            Image(systemName: model.systemImage ?? "plus")
                .tonyText(.heading)
                .foregroundStyle(TonyColor.onCta)
                .frame(width: diameter, height: diameter)
                .glassEffect(.regular.tint(TonyColor.cta).interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.title)
        .accessibilityIdentifier(ifPresent: model.accessibilityIdentifier)
        // It doesn't grow past the largest standard size; a long press shows the large content viewer.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer {
            Label(model.title, systemImage: model.systemImage ?? "plus")
        }
    }
}

extension View {
    /// Floats the button at the bottom trailing corner, above the tab bar. Scrolled content can scroll out from under it.
    public func floatingButton(_ model: ButtonDataModel) -> some View {
        safeAreaInset(edge: .bottom, alignment: .trailing) {
            FloatingButton(model)
                .padding([.trailing, .bottom], TonySpacing.page)
        }
    }
}

#if DEBUG
#Preview("Floating button") {
    TonyColor.canvas
        .floatingButton(ButtonDataModel(title: "Add a task", systemImage: "plus", action: Action(id: "preview") { _ in }))
        .tonyPreview(padding: 0)
}
#endif
