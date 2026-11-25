import SwiftUI
import TonyUIModels
import UIKit

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

/// Toggles drawn as tiles, an emoji above the title, as many per line as fit.
/// A tile that is on is outlined in the accent colour and checked.
public struct IconToggleGrid: View {
    private let items: [IconToggleDataModel]
    @ScaledMetric(relativeTo: .body) private var minimumWidth = TonySize.iconToggleTile

    public init(_ items: [IconToggleDataModel]) {
        self.items = items
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: TonySpacing.snug)], spacing: TonySpacing.snug) {
            ForEach(items) { IconToggleTile(model: $0) }
        }
    }
}

private struct IconToggleTile: View {
    let model: IconToggleDataModel
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = TonySize.tileIcon

    var body: some View {
        Button {
            model.onChange.execute(!model.isOn)
        } label: {
            VStack(spacing: TonySpacing.tight) {
                Text(model.icon)
                    .font(.system(size: iconSize))
                HStack(alignment: .firstTextBaseline, spacing: TonySpacing.xSmall) {
                    if model.isOn {
                        Image(systemName: "checkmark")
                    }
                    Text(model.title)
                        .lineLimit(2, reservesSpace: true)
                }
                .tonyText(model.isOn ? .labelStrong : .label)
                .foregroundStyle(model.isOn ? TonyColor.ink : TonyColor.muted)
                .multilineTextAlignment(.center)
            }
            .padding(.vertical, TonySpacing.large)
            .padding(.horizontal, TonySpacing.small)
            .frame(maxWidth: .infinity, minHeight: TonySize.touchTarget)
            .background(TonyColor.glass, in: .rect(cornerRadius: TonyRadius.row))
            .overlay {
                RoundedRectangle(cornerRadius: TonyRadius.row)
                    .strokeBorder(model.isOn ? TonyColor.accent : TonyColor.glassEdge, lineWidth: model.isOn ? TonySize.border : TonySize.glassEdge)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.title)
        .accessibilityAddTraits(model.isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(ifPresent: model.accessibilityIdentifier)
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

/// A task's emoji on a dark round, with a pen that says it can be changed.
/// Tapping it opens the emoji keyboard; the emoji picked replaces the one shown.
public struct IconField: View {
    private let model: TextFieldDataModel
    @ScaledMetric(relativeTo: .largeTitle) private var size = TonySize.taskIcon
    @ScaledMetric(relativeTo: .largeTitle) private var badge = TonySize.editBadge

    public init(_ model: TextFieldDataModel) {
        self.model = model
    }

    public var body: some View {
        EmojiTextField(model: model, fontSize: size * 0.6)
            .frame(width: size, height: size)
            .background(TonyColor.glassBar, in: .circle)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "pencil")
                    .font(.system(size: badge * 0.55, weight: .semibold))
                    .foregroundStyle(TonyColor.ink)
                    .frame(width: badge, height: badge)
                    .background(TonyColor.surface, in: .circle)
                    .overlay { Circle().strokeBorder(TonyColor.glassEdge, lineWidth: TonySize.glassEdge) }
                    .offset(x: badge * 0.25, y: badge * 0.15)
                    .accessibilityHidden(true)
            }
            .frame(minWidth: TonySize.touchTarget, minHeight: TonySize.touchTarget)
    }
}

/// A text field that opens on the emoji keyboard, shows one emoji, and closes once one is picked.
private struct EmojiTextField: UIViewRepresentable {
    let model: TextFieldDataModel
    let fontSize: CGFloat

    func makeUIView(context: Context) -> EmojiKeyboardField {
        let field = EmojiKeyboardField()
        field.textAlignment = .center
        field.tintColor = .clear
        field.borderStyle = .none
        field.adjustsFontSizeToFitWidth = true
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.began(_:)), for: .editingDidBegin)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.addTarget(context.coordinator, action: #selector(Coordinator.ended(_:)), for: .editingDidEnd)
        return field
    }

    func updateUIView(_ field: EmojiKeyboardField, context: Context) {
        context.coordinator.model = model
        field.text = model.text
        field.font = .systemFont(ofSize: fontSize)
        field.accessibilityLabel = model.title
        field.accessibilityIdentifier = model.accessibilityIdentifier
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    @MainActor
    final class Coordinator: NSObject {
        var model: TextFieldDataModel

        init(model: TextFieldDataModel) {
            self.model = model
        }

        /// The field empties while the keyboard is up, so the emoji picked is all it holds.
        @objc func began(_ field: UITextField) {
            field.text = ""
        }

        @objc func changed(_ field: UITextField) {
            guard let text = field.text, !text.isEmpty else { return }
            model.onChange.execute(text)
            field.resignFirstResponder()
        }

        /// Closing the keyboard without picking one shows the icon again.
        @objc func ended(_ field: UITextField) {
            if field.text?.isEmpty ?? true {
                field.text = model.text
            }
        }
    }
}

/// Asks for the emoji keyboard when the user has it; the usual keyboard otherwise.
private final class EmojiKeyboardField: UITextField {
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
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
        .background(TonyColor.surfaceRaised)
    }
    .tonyPreview(padding: 0)
}

#Preview("Icon field") {
    IconField(TextFieldDataModel(title: "Icon", text: "🪴", onChange: Action(id: "preview") { _ in }))
        .tonyPreview()
}

#Preview("Icon toggle grid") {
    let weather = [("☀️", "Clear", true), ("🌤️", "Fair", true), ("⛅️", "Partly cloudy", false), ("☁️", "Cloudy", false), ("🌫️", "Fog", false), ("🌧️", "Rain", false)]
    IconToggleGrid(weather.map { icon, title, isOn in
        IconToggleDataModel(id: title, icon: icon, title: title, isOn: isOn, onChange: Action(id: "preview") { _ in })
    })
    .tonyPreview()
}
#endif
