import Foundation
import Observation
import TonyCore

/// The permission sheet, and where each permission stands. Only `PermissionStore` writes to it.
@MainActor
@Observable
final class PermissionState {
    /// The permission the sheet explains. It stays set while the sheet closes, so its text does not vanish.
    var permission: Permission?
    var isAsking = false
    var statuses: [Permission: PermissionStatus] = [:]
}
