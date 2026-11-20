import CoreText
import SwiftUI

/// The Figma type styles (`Tony/*`). The display, Tony's briefing and numerals use Lekton; the rest uses the system font where Figma has Inter.
public enum TonyTextStyle: Sendable, CaseIterable {
    case display
    /// What Tony says about the day.
    case briefing
    case heading
    case numeral
    /// What the user types in the task composer.
    case titleLarge
    /// A task's name at the top of its form.
    case title
    case bodyLarge
    case body
    case bodySmall
    case caption
    case labelLarge
    case label
    case labelSmall
    case labelStrong

    var size: CGFloat {
        switch self {
        case .display: 21
        case .briefing: 17
        case .heading: 22
        case .numeral: 26
        case .titleLarge: 22
        case .title: 20
        case .bodyLarge: 17
        case .body, .label, .labelStrong: 14
        case .bodySmall: 13
        case .caption, .labelSmall: 12
        case .labelLarge: 16
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display, .heading, .titleLarge, .title, .bodyLarge, .body, .bodySmall, .caption: .regular
        case .labelLarge, .label, .labelSmall: .medium
        case .labelStrong: .semibold
        case .briefing, .numeral: .bold
        }
    }

    var usesLekton: Bool {
        switch self {
        case .display, .briefing, .numeral: true
        default: false
        }
    }

    /// The system text style whose Dynamic Type scaling this style follows.
    var scalesWith: Font.TextStyle {
        switch self {
        case .display, .heading, .numeral, .titleLarge: .title2
        case .title: .title3
        case .bodyLarge, .briefing: .body
        case .labelLarge: .callout
        case .body, .label, .labelStrong: .subheadline
        case .bodySmall: .footnote
        case .caption, .labelSmall: .caption
        }
    }

    func font(size: CGFloat) -> Font {
        guard usesLekton, Lekton.isRegistered else {
            return .system(size: size, weight: weight, design: usesLekton ? .monospaced : .default)
        }
        return .custom(weight == .bold ? Lekton.bold : Lekton.regular, fixedSize: size)
    }
}

extension View {
    /// Applies a Tony type style, scaled with Dynamic Type.
    public func tonyText(_ style: TonyTextStyle) -> some View {
        modifier(TonyTextModifier(style: style))
    }
}

private struct TonyTextModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let style: TonyTextStyle

    init(style: TonyTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.scalesWith)
    }

    func body(content: Content) -> some View {
        content.font(style.font(size: size))
    }
}

private enum Lekton {
    static let regular = "Lekton-Regular"
    static let bold = "Lekton-Bold"

    /// Fonts in a framework are not picked up from Info.plist, so the files are registered on first use.
    static let isRegistered: Bool = {
        let urls = [regular, bold].compactMap { Bundle.design.url(forResource: $0, withExtension: "ttf") }
        guard urls.count == 2 else {
            return false
        }
        return urls.allSatisfy { CTFontManagerRegisterFontsForURL($0 as CFURL, .process, nil) }
    }()
}
