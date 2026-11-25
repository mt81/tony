import Foundation

/// A system permission Tony asks for, only after the user taps a call to action that needs it.
public enum Permission: String, Sendable, CaseIterable {
    case calendar
}

public enum PermissionStatus: String, Sendable, CaseIterable {
    case notDetermined
    case granted
    case denied
}

/// One system permission: where it stands, and the system prompt that asks for it.
public protocol PermissionProvider: Sendable {
    var permission: Permission { get }
    func status() async -> PermissionStatus
    /// Shows the system prompt if the user has not answered yet, and returns where things stand.
    func request() async -> PermissionStatus
}
