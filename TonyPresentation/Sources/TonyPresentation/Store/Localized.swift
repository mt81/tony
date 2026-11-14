import Foundation

/// The text for a key of this package's String Catalog, in the locale's language.
func localized(_ key: String.LocalizationValue, _ locale: Locale) -> String {
    var resource = LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    resource.locale = locale
    return String(localized: resource)
}
