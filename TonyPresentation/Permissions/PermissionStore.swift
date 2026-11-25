import Foundation
import TonyCore

/// The permission manager. A feature asks it for a permission after the user taps a call to action:
/// it shows the permission sheet, asks the system through the permission's provider when the user agrees,
/// closes the sheet and returns the answer. Features never show the system prompt themselves.
@MainActor
public final class PermissionStore {
    let state = PermissionState()

    private let providers: [Permission: any PermissionProvider]
    private let openSettings: @MainActor () -> Void
    private var answer: CheckedContinuation<PermissionStatus, Never>?

    /// `openSettings` opens Tony's page in the Settings app, where a refused permission can be turned on.
    public init(providers: [any PermissionProvider], openSettings: @escaping @MainActor () -> Void) {
        self.providers = Dictionary(providers.map { ($0.permission, $0) }) { first, _ in first }
        self.openSettings = openSettings
    }

    /// Where the permission stands, without asking anything.
    public func status(of permission: Permission) async -> PermissionStatus {
        guard let provider = providers[permission] else { return .notDetermined }
        let status = await provider.status()
        state.statuses[permission] = status
        return status
    }

    /// Shows the permission sheet, and returns once the user has answered and the sheet has closed.
    /// A permission already granted returns at once, without the sheet.
    public func request(_ permission: Permission) async -> PermissionStatus {
        let status = await status(of: permission)
        guard status != .granted, providers[permission] != nil else { return status }
        finish(with: state.permission.flatMap { state.statuses[$0] } ?? .notDetermined)
        state.permission = permission
        state.isAsking = true
        return await withCheckedContinuation { answer = $0 }
    }

    /// The sheet's main button: the system prompt, or Settings when the user already refused.
    func grant() async {
        guard state.isAsking, let permission = state.permission, let provider = providers[permission] else { return }
        if state.statuses[permission] == .denied {
            openSettings()
            finish(with: .denied)
            return
        }
        let status = await provider.request()
        state.statuses[permission] = status
        finish(with: status)
    }

    /// Not now, or the sheet swiped away: nothing is asked.
    func notNow() {
        guard state.isAsking else { return }
        finish(with: state.permission.flatMap { state.statuses[$0] } ?? .notDetermined)
    }

    private func finish(with status: PermissionStatus) {
        state.isAsking = false
        answer?.resume(returning: status)
        answer = nil
    }
}
