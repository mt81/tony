import SwiftUI
import TonyUIModels

/// Debug builds only: the evaluation set and its report, to check the on-device model on a device.
public struct ModelCheckScreen: View {
    private let model: ModelCheckScreenDataModel

    public init(_ model: ModelCheckScreenDataModel) {
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
                    if let report = model.report {
                        Text(report)
                            .tonyText(.caption)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("modelReport")
                        ShareLink(model.shareReport, item: report)
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
