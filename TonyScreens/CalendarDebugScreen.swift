import SwiftUI
import TonyPresentation
import TonyUIKit
import TonyUIModels

/// Debug builds only: today's blocks as the planner sees them, to check the calendar on a device.
public struct CalendarDebugScreen: View {
    private let model: CalendarDebugScreenDataModel

    public init(_ model: CalendarDebugScreenDataModel) {
        self.model = model
    }

    public var body: some View {
        List {
            Section {
                Text(model.access)
                    .tonyText(.label)
                    .accessibilityIdentifier("calendarAccess")
                if let requestAccess = model.requestAccess {
                    ButtonView(requestAccess)
                }
                ButtonView(model.refresh)
            } footer: {
                if let plannedAt = model.plannedAt {
                    Text(plannedAt)
                }
            }
            Section {
                ForEach(model.rows) { row in
                    VStack(alignment: .leading, spacing: TonySpacing.hairline) {
                        Text(row.time)
                            .tonyText(.labelLarge)
                            .foregroundStyle(row.isBusy ? TonyColor.warning : TonyColor.ink)
                        Text(row.detail)
                            .tonyText(.caption)
                            .foregroundStyle(TonyColor.muted)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(TonyColor.canvas)
        .navigationTitle(model.title)
        .onAppear(perform: model.onAppear)
    }
}

#if DEBUG
#Preview("Calendar check") {
    NavigationStack {
        CalendarDebugScreen(PreviewSamples.calendarDebug)
    }
    .tonyPreview(padding: 0)
}
#endif
