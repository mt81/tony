import SwiftUI
import TonyPresentation
import TonyUIKit
import TonyUIModels

/// The You tab, drawn from its view model. Each part reads only its own values, so it redraws on its own.
public struct YouScreen: View {
    private let viewModel: YouViewModel

    public init(_ viewModel: YouViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TonySpacing.section) {
                YouHeader(viewModel: viewModel)
                RoutineCard(viewModel: viewModel)
                CalendarCard(viewModel: viewModel)
            }
            .padding(.horizontal, TonySpacing.page)
            .padding(.top, TonySpacing.small)
            .padding(.bottom, TonySpacing.section)
        }
        .background { PageBackground() }
        .task { await viewModel.load() }
        .sheet(isPresented: Binding(get: { viewModel.isEditing }, set: { if !$0 { viewModel.dismissEditor() } })) {
            RoutineEditorSheet(viewModel: viewModel)
        }
        .alert(viewModel.alert)
    }
}

private struct YouHeader: View {
    let viewModel: YouViewModel

    var body: some View {
        HStack(spacing: TonySpacing.inset) {
            if let initial = viewModel.initial {
                Text(initial)
                    .tonyText(.heading)
                    .foregroundStyle(TonyColor.ink)
                    .frame(width: TonySize.avatar, height: TonySize.avatar)
                    .background(TonyColor.surfaceRaised, in: .circle)
                    .accessibilityHidden(true)
            }
            Text(viewModel.name)
                .tonyText(.display)
                .foregroundStyle(TonyColor.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("youName")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RoutineCard: View {
    let viewModel: YouViewModel

    var body: some View {
        let routine = viewModel.routine
        YouCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: TonySpacing.small) {
                    YouCardTitle(routine.title)
                    Spacer()
                    editButton(routine.edit)
                }
                VStack(alignment: .leading, spacing: 0) {
                    YouCardTitle(routine.title)
                    editButton(routine.edit)
                }
            }
            ForEach(routine.lines, id: \.self) { line in
                YouCardText(line)
            }
        }
    }

    private func editButton(_ edit: ButtonDataModel) -> some View {
        Button {
            edit.action()
        } label: {
            Text(edit.title)
                .tonyText(.caption)
                .foregroundStyle(TonyColor.muted)
                .frame(minWidth: TonySize.touchTarget, minHeight: TonySize.touchTarget, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ifPresent: edit.accessibilityIdentifier)
    }
}

private struct CalendarCard: View {
    let viewModel: YouViewModel

    var body: some View {
        let calendar = viewModel.calendar
        YouCard {
            YouCardTitle(calendar.title)
            YouCardText(calendar.text)
                .accessibilityIdentifier("calendarAccess")
            if let allow = calendar.allow {
                Button {
                    allow.action()
                } label: {
                    Chip(ChipDataModel(title: allow.title, style: .accent))
                        .frame(minHeight: TonySize.touchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(ifPresent: allow.accessibilityIdentifier)
            }
        }
    }
}

private struct RoutineEditorSheet: View {
    let viewModel: YouViewModel

    var body: some View {
        if let editor = viewModel.editor {
            RoutineEditorScreen(editor)
        }
    }
}

private struct YouCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: TonySpacing.small) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TonySpacing.panelInset)
            .background(TonyColor.surface, in: .rect(cornerRadius: TonyRadius.tile))
    }
}

private struct YouCardTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .tonyText(.heading)
            .foregroundStyle(TonyColor.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct YouCardText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .tonyText(.body)
            .foregroundStyle(TonyColor.muted)
    }
}

#if DEBUG
#Preview("You") {
    YouScreen(.preview())
        .tonyPreview(padding: 0)
}

#Preview("You, no name, calendar allowed") {
    YouScreen(.preview(name: "", canAllowCalendar: false))
        .tonyPreview(padding: 0)
}

#Preview("You, editing") {
    YouScreen(.preview(isEditing: true))
        .tonyPreview(padding: 0)
}

#Preview("You, largest text") {
    YouScreen(.preview())
        .tonyPreview(padding: 0)
        .dynamicTypeSize(.accessibility5)
}
#endif
