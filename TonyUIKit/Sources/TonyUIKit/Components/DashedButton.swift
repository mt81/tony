import SwiftUI
import TonyUIModels

/// A quiet, full-width button with a dashed outline, for adding something to a list.
public struct DashedButton: View {
    private let model: ButtonDataModel

    public init(_ model: ButtonDataModel) {
        self.model = model
    }

    public var body: some View {
        Button(action: model.action) {
            Text(model.title)
                .tonyText(.label)
                .foregroundStyle(TonyColor.muted)
                .frame(maxWidth: .infinity, minHeight: TonySize.touchTarget)
                .padding(.vertical, TonySpacing.xSmall)
                .overlay {
                    RoundedRectangle(cornerRadius: TonyRadius.row)
                        .strokeBorder(TonyColor.line, style: StrokeStyle(lineWidth: TonySize.border, dash: [TonySpacing.tight]))
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ifPresent: model.accessibilityIdentifier)
    }
}

#if DEBUG
#Preview("Dashed button") {
    DashedButton(ButtonDataModel(title: "+ Add a task") {})
        .tonyPreview()
}
#endif
