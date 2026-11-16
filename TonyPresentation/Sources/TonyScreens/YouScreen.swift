import SwiftUI
import TonyPresentation
import TonyUIKit
import TonyUIModels

/// The You tab, drawn from its data model.
public struct YouScreen: View {
    private let model: YouScreenDataModel

    public init(_ model: YouScreenDataModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TonySpacing.section) {
                header
                routine
                calendar
            }
            .padding(.horizontal, TonySpacing.page)
            .padding(.top, TonySpacing.small)
            .padding(.bottom, TonySpacing.section)
        }
        .background { PageBackground() }
        .onAppear(perform: model.onAppear)
        .sheet(item: Binding(get: { model.editor }, set: { if $0 == nil { model.dismissEditor() } })) { editor in
            RoutineEditorScreen(editor)
        }
        .alert(model.alert)
    }

    private var header: some View {
        HStack(spacing: TonySpacing.inset) {
            if let initial = model.initial {
                Text(initial)
                    .tonyText(.heading)
                    .foregroundStyle(TonyColor.ink)
                    .frame(width: TonySize.avatar, height: TonySize.avatar)
                    .background(TonyColor.surfaceRaised, in: .circle)
                    .accessibilityHidden(true)
            }
            Text(model.name)
                .tonyText(.display)
                .foregroundStyle(TonyColor.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("youName")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var routine: some View {
        card {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: TonySpacing.small) {
                    cardTitle(model.routine.title)
                    Spacer()
                    editButton
                }
                VStack(alignment: .leading, spacing: 0) {
                    cardTitle(model.routine.title)
                    editButton
                }
            }
            ForEach(model.routine.lines, id: \.self) { line in
                cardText(line)
            }
        }
    }

    private var editButton: some View {
        Button(action: model.routine.edit.action) {
            Text(model.routine.edit.title)
                .tonyText(.caption)
                .foregroundStyle(TonyColor.muted)
                .frame(minWidth: TonySize.touchTarget, minHeight: TonySize.touchTarget, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ifPresent: model.routine.edit.accessibilityIdentifier)
    }

    private var calendar: some View {
        card {
            cardTitle(model.calendar.title)
            cardText(model.calendar.text)
                .accessibilityIdentifier("calendarAccess")
            if let allow = model.calendar.allow {
                Button(action: allow.action) {
                    Chip(ChipDataModel(title: allow.title, style: .accent))
                        .frame(minHeight: TonySize.touchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(ifPresent: allow.accessibilityIdentifier)
            }
        }
    }

    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: TonySpacing.small, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TonySpacing.panelInset)
            .background(TonyColor.surface, in: .rect(cornerRadius: TonyRadius.tile))
    }

    private func cardTitle(_ title: String) -> some View {
        Text(title)
            .tonyText(.heading)
            .foregroundStyle(TonyColor.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private func cardText(_ text: String) -> some View {
        Text(text)
            .tonyText(.body)
            .foregroundStyle(TonyColor.muted)
    }
}

#if DEBUG
#Preview("You") {
    YouScreen(PreviewSamples.you())
        .tonyPreview(padding: 0)
}

#Preview("You, no name, calendar allowed") {
    YouScreen(PreviewSamples.you(name: "", canAllowCalendar: false))
        .tonyPreview(padding: 0)
}

#Preview("You, largest text") {
    YouScreen(PreviewSamples.you())
        .tonyPreview(padding: 0)
        .dynamicTypeSize(.accessibility5)
}
#endif
