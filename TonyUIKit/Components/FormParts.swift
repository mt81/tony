import SwiftUI
import TonyUIModels

/// A box to type a sentence in, docked above the keyboard, with a button that sends it.
public struct Composer: View {
    private let model: ComposerDataModel
    @FocusState private var isFocused: Bool

    public init(_ model: ComposerDataModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TonySpacing.inset) {
            TextField(
                model.text.title,
                text: Binding(get: { model.text.text }, set: { model.text.onChange.execute($0) }),
                prompt: Text(model.text.prompt ?? model.text.title),
                axis: .vertical
            )
            .tonyText(.titleLarge)
            .foregroundStyle(TonyColor.ink)
            .lineLimit(1...6)
            .submitLabel(.send)
            .focused($isFocused)
            .disabled(model.isSending)
            .accessibilityIdentifier(ifPresent: model.text.accessibilityIdentifier)
            HStack {
                Image(systemName: "sparkle")
                    .tonyText(.caption)
                    .foregroundStyle(TonyColor.accent)
                    .accessibilityHidden(true)
                Spacer()
                sendButton
            }
        }
        .padding(.top, TonySpacing.page)
        .padding(.leading, TonySpacing.page)
        .padding([.trailing, .bottom], TonySpacing.medium)
        .background(TonyColor.glass, in: .rect(cornerRadius: TonyRadius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: TonyRadius.panel).strokeBorder(TonyColor.glassEdge, lineWidth: TonySize.glassEdge)
        }
        .onAppear { isFocused = true }
    }

    private var sendButton: some View {
        Button {
            model.send.action.execute()
        } label: {
            ZStack {
                if model.isSending {
                    ProgressView().tint(TonyColor.onAccent)
                } else {
                    Image(systemName: model.send.systemImage ?? "arrow.up")
                        .tonyText(.heading)
                        .foregroundStyle(TonyColor.onAccent)
                }
            }
            .padding(TonySpacing.snug)
            .frame(minWidth: TonySize.touchTarget, minHeight: TonySize.touchTarget)
            .background(TonyColor.accent, in: .circle)
            .opacity(model.send.isEnabled || model.isSending ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!model.send.isEnabled)
        .accessibilityLabel(model.send.title)
        .accessibilityIdentifier(ifPresent: model.send.accessibilityIdentifier)
    }
}

/// The label of a form row that opens a page: icon and title, then the value. A navigation link adds the chevron,
/// and carries the row's accessibility identifier.
public struct DetailRow: View {
    private let model: DetailRowDataModel

    public init(_ model: DetailRowDataModel) {
        self.model = model
    }

    public var body: some View {
        LabeledContent {
            Text(model.value)
                .tonyText(.bodyLarge)
                .foregroundStyle(TonyColor.muted)
        } label: {
            Label {
                Text(model.title)
                    .tonyText(.bodyLarge)
                    .foregroundStyle(TonyColor.ink)
            } icon: {
                Image(systemName: model.systemImage)
                    .foregroundStyle(TonyColor.muted)
            }
        }
        .frame(minHeight: TonySize.touchTarget)
    }
}

/// A row of a list of choices, checked when on. Tapping it turns it on or off.
public struct CheckmarkRow: View {
    private let model: ToggleDataModel

    public init(_ model: ToggleDataModel) {
        self.model = model
    }

    public var body: some View {
        Button {
            model.onChange.execute(!model.isOn)
        } label: {
            HStack {
                Text(model.title)
                    .tonyText(.bodyLarge)
                    .foregroundStyle(TonyColor.ink)
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundStyle(TonyColor.accent)
                    .opacity(model.isOn ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: TonySize.touchTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.isOn ? .isSelected : [])
    }
}

/// The header of a section of glass rows.
public struct FormSectionHeader: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .tonyText(.labelLarge)
            .foregroundStyle(TonyColor.muted)
            .textCase(nil)
    }
}

extension View {
    /// A list row on a glass card, with glass lines between rows.
    public func glassRow() -> some View {
        listRowBackground(TonyColor.glass)
            .listRowSeparatorTint(TonyColor.glassEdge)
    }
}

/// The background of the task form: stars over the raised surface.
public struct NightSky: View {
    public init() {}

    public var body: some View {
        TonyColor.surfaceRaised
            .overlay(alignment: .top) {
                Image("NightSky", bundle: .design)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()
    }
}

#if DEBUG
#Preview("Composer") {
    VStack(spacing: TonySpacing.large) {
        Composer(
            ComposerDataModel(
                text: TextFieldDataModel(title: "Describe your task", text: "", prompt: "Water the plants every 5 days", onChange: Action(id: "preview") { _ in }),
                send: ButtonDataModel(title: "Send", systemImage: "arrow.up", isEnabled: false, action: Action(id: "preview") { _ in }),
                isSending: false
            )
        )
        Composer(
            ComposerDataModel(
                text: TextFieldDataModel(title: "Describe your task", text: "Do dark clothes laundry every two weeks", onChange: Action(id: "preview") { _ in }),
                send: ButtonDataModel(title: "Send", systemImage: "arrow.up", action: Action(id: "preview") { _ in }),
                isSending: false
            )
        )
        Composer(
            ComposerDataModel(
                text: TextFieldDataModel(title: "Describe your task", text: "Do dark clothes laundry every two weeks", onChange: Action(id: "preview") { _ in }),
                send: ButtonDataModel(title: "Send", systemImage: "arrow.up", isEnabled: false, action: Action(id: "preview") { _ in }),
                isSending: true
            )
        )
    }
    .tonyPreview()
}

#Preview("Form rows") {
    NavigationStack {
        List {
            Section {
                NavigationLink {} label: {
                    DetailRow(DetailRowDataModel(systemImage: "repeat", title: "Repeats", value: "Every 2 weeks"))
                }
                NavigationLink {} label: {
                    DetailRow(DetailRowDataModel(systemImage: "checkmark.circle", title: "Counted from", value: "Last time done"))
                }
            } header: {
                FormSectionHeader("Schedule")
            }
            .glassRow()
            Section {
                CheckmarkRow(ToggleDataModel(id: "any", title: "Any time", isOn: false, onChange: Action(id: "preview") { _ in }))
                CheckmarkRow(ToggleDataModel(id: "morning", title: "Morning", isOn: true, onChange: Action(id: "preview") { _ in }))
            }
            .glassRow()
        }
        .scrollContentBackground(.hidden)
        .background { NightSky() }
    }
    .tonyPreview(padding: 0)
}

#Preview("Night sky") {
    NightSky()
        .preferredColorScheme(.dark)
}
#endif
