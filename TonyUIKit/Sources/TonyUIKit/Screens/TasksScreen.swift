import SwiftUI
import TonyUIModels

/// The Tasks tab, drawn from its data model.
public struct TasksScreen: View {
    private let model: TasksScreenDataModel

    public init(_ model: TasksScreenDataModel) {
        self.model = model
    }

    public var body: some View {
        List {
            header
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        taskRow(row)
                    }
                    .onMove(perform: section.move)
                } header: {
                    sectionHeader(section)
                }
            }
            addTaskRow
        }
        .listStyle(.plain)
        .listRowSpacing(TonySpacing.small)
        .scrollContentBackground(.hidden)
        .background {
            LinearGradient(
                stops: [.init(color: TonyColor.glow, location: 0), .init(color: TonyColor.canvas, location: 0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .onAppear(perform: model.onAppear)
        .sheet(item: Binding(get: { model.editor }, set: { if $0 == nil { model.dismissEditor() } })) { editor in
            TaskEditorScreen(editor)
        }
        .alert(model.alert)
    }

    private var header: some View {
        HStack(spacing: TonySpacing.medium) {
            Text(model.title)
                .tonyText(.display)
                .foregroundStyle(TonyColor.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: model.add.action) {
                Image(systemName: model.add.systemImage ?? "plus")
                    .tonyText(.heading)
                    .foregroundStyle(TonyColor.onAccent)
                    .padding(TonySpacing.snug)
                    .frame(minWidth: TonySize.touchTarget, minHeight: TonySize.touchTarget)
                    .background(TonyColor.accent, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.add.title)
            .accessibilityIdentifier(ifPresent: model.add.accessibilityIdentifier)
        }
        .plainRow()
    }

    private func sectionHeader(_ section: TaskSectionDataModel) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: TonySpacing.small) {
                sectionTitle(section.title)
                Spacer()
                sectionHint(section.hint)
            }
            VStack(alignment: .leading, spacing: TonySpacing.xSmall) {
                sectionTitle(section.title)
                sectionHint(section.hint)
            }
        }
        .textCase(nil)
        .padding(.top, TonySpacing.large)
        .listRowInsets(EdgeInsets(top: 0, leading: TonySpacing.page, bottom: TonySpacing.small, trailing: TonySpacing.page))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .tonyText(.heading)
            .foregroundStyle(TonyColor.ink)
            .fixedSize()
    }

    @ViewBuilder
    private func sectionHint(_ hint: String?) -> some View {
        if let hint {
            Text(hint)
                .tonyText(.caption)
                .foregroundStyle(TonyColor.muted)
        }
    }

    private func taskRow(_ row: TaskRowDataModel) -> some View {
        Button(action: row.open) {
            TaskRow(row)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(row.accessibilityIdentifier)
        .swipeActions {
            ButtonView(row.delete)
        }
        .plainRow()
    }

    private var addTaskRow: some View {
        Button(action: model.addTask.action) {
            Text(model.addTask.title)
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
        .padding(.top, TonySpacing.small)
        .plainRow()
    }
}

extension View {
    /// A list row that shows only its content: no separator, no system background, page margins.
    fileprivate func plainRow() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: TonySpacing.page, bottom: 0, trailing: TonySpacing.page))
    }
}
