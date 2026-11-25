import Foundation

/// The text for a key of this framework's String Catalog, in the locale's language.
func localized(_ key: String.LocalizationValue, _ locale: Locale) -> String {
    var resource = LocalizedStringResource(key, bundle: .atURL(#bundle.bundleURL))
    resource.locale = locale
    return String(localized: resource)
}

/// The text for a key of this framework's String Catalog, in the locale's language, with its Markdown read:
/// `*light*` in "A *light* day" is emphasised.
func localizedAttributed(_ key: String.LocalizationValue, _ locale: Locale) -> AttributedString {
    var resource = LocalizedStringResource(key, bundle: .atURL(#bundle.bundleURL))
    resource.locale = locale
    return AttributedString(localized: resource)
}
