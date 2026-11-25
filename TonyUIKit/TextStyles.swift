import CoreText
import SwiftUI

/// The Figma type styles (`Tony Light/*`). Titles, headings and numerals use Unbounded; the rest uses Lexend.
public enum TonyTextStyle: Sendable, CaseIterable {
    /// The headline of the day.
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
        case .display: 24
        case .numeral: 22
        case .titleLarge: 20
        case .heading: 18
        case .title: 17
        case .bodyLarge: 16
        case .briefing, .labelLarge: 15
        case .body, .label, .labelStrong: 13
        case .bodySmall: 12
        case .caption, .labelSmall: 11
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .display: 31
        case .numeral: 30
        case .titleLarge: 28
        case .heading: 26
        case .briefing: 25
        case .title, .bodyLarge: 24
        case .labelLarge: 21
        case .body: 19
        case .label, .labelStrong: 18
        case .bodySmall: 17
        case .caption, .labelSmall: 15
        }
    }

    var weight: Font.Weight {
        switch self {
        case .briefing, .titleLarge, .title, .bodyLarge, .body, .bodySmall, .caption: .regular
        case .labelLarge, .label, .labelSmall: .medium
        case .heading, .labelStrong: .semibold
        case .display, .numeral: .bold
        }
    }

    var family: TonyFont {
        switch self {
        case .display, .heading, .numeral: .unbounded
        default: .lexend
        }
    }

    /// The system text style whose Dynamic Type scaling this style follows.
    var scalesWith: Font.TextStyle {
        switch self {
        case .display, .numeral: .title2
        case .heading, .titleLarge, .title: .title3
        case .bodyLarge, .briefing: .body
        case .labelLarge: .callout
        case .body, .label, .labelStrong: .subheadline
        case .bodySmall: .footnote
        case .caption, .labelSmall: .caption
        }
    }

    func font(size: CGFloat) -> Font {
        guard TonyFont.areRegistered else {
            return .system(size: size, weight: weight)
        }
        return .custom(family.rawValue, fixedSize: size).weight(weight)
    }
}

extension AttributedString {
    /// Draws the emphasised words in the accent instead of italics: "A *light* day".
    public func accented() -> AttributedString {
        var text = self
        for run in text.runs where run.inlinePresentationIntent?.contains(.emphasized) == true {
            text[run.range].inlinePresentationIntent = nil
            text[run.range].foregroundColor = TonyColor.accentText
        }
        return text
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
        content
            .font(style.font(size: size))
            .lineHeight(.exact(points: style.lineHeight * size / style.size))
    }
}

/// The two variable fonts of the Figma file, by family name.
enum TonyFont: String {
    case unbounded = "Unbounded"
    case lexend = "Lexend"

    /// Fonts in a framework are not picked up from Info.plist, so the files are registered on first use.
    static let areRegistered: Bool = {
        let urls = [unbounded, lexend].compactMap { Bundle.design.url(forResource: $0.rawValue, withExtension: "ttf") }
        guard urls.count == 2 else {
            return false
        }
        return urls.allSatisfy { CTFontManagerRegisterFontsForURL($0 as CFURL, .process, nil) }
    }()
}
