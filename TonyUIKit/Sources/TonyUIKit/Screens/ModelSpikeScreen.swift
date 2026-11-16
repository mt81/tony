import SwiftUI
import TonyUIModels

/// Debug builds only: the model spikes and their results, to check the on-device model on a device.
public struct ModelSpikeScreen: View {
    private let model: ModelSpikeScreenDataModel

    public init(_ model: ModelSpikeScreenDataModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(model.availability)
                        .tonyText(.label)
                        .accessibilityIdentifier("modelAvailability")
                    ButtonView(model.run)
                    if let summary = model.summary {
                        Text(summary)
                            .tonyText(.labelStrong)
                            .accessibilityIdentifier("modelSummary")
                    }
                }
                Section {
                    ForEach(model.extensionChecks, id: \.self) { line in
                        Text(line).tonyText(.caption)
                    }
                    ButtonView(model.requestBackgroundCheck)
                    if let request = model.backgroundCheckRequest {
                        Text(request).tonyText(.caption)
                    }
                }
                Section {
                    ForEach(model.rows) { row in
                        VStack(alignment: .leading, spacing: TonySpacing.xSmall) {
                            Text(row.title)
                                .tonyText(.labelLarge)
                                .foregroundStyle(TonyColor.ink)
                            Text(row.input)
                                .tonyText(.caption)
                                .foregroundStyle(TonyColor.muted)
                            if let output = row.output {
                                Text(output)
                                    .tonyText(.body)
                                    .foregroundStyle(TonyColor.ink)
                            }
                            Text(row.verdict)
                                .tonyText(.labelSmall)
                                .foregroundStyle(row.hasPassed == false ? TonyColor.warning : TonyColor.accent)
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
}
