import CoreText
import SwiftUI

/// The Figma type styles (`Tony/*`). Titles and numerals use Sometype Mono; the rest uses the system font where Figma has Inter.
public enum TonyTextStyle: Sendable, CaseIterable {
    case display
    case heading
    case numeral
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
        case .heading: 22
        case .numeral: 26
        case .bodyLarge: 17
        case .body, .label, .labelStrong: 14
        case .bodySmall: 13
        case .caption, .labelSmall: 12
        case .labelLarge: 16
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display, .heading, .bodyLarge, .body, .bodySmall, .caption: .regular
        case .labelLarge, .label, .labelSmall: .medium
        case .numeral, .labelStrong: .semibold
        }
    }

    var usesSometypeMono: Bool {
        switch self {
        case .display, .heading, .numeral: true
        default: false
        }
    }

    /// The system text style whose Dynamic Type scaling this style follows.
    var scalesWith: Font.TextStyle {
        switch self {
        case .display, .heading, .numeral: .title2
        case .bodyLarge: .body
        case .labelLarge: .callout
        case .body, .label, .labelStrong: .subheadline
        case .bodySmall: .footnote
        case .caption, .labelSmall: .caption
        }
    }

    func font(size: CGFloat) -> Font {
        guard usesSometypeMono, SometypeMono.isRegistered else {
            return .system(size: size, weight: weight, design: usesSometypeMono ? .monospaced : .default)
        }
        return .custom(SometypeMono.familyName, fixedSize: size).weight(weight)
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

private enum SometypeMono {
    static let familyName = "Sometype Mono"

    /// Fonts in a framework are not picked up from Info.plist, so the file is registered on first use.
    static let isRegistered: Bool = {
        guard let url = Bundle.design.url(forResource: "SometypeMono", withExtension: "ttf") else {
            return false
        }
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()
}
