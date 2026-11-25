import Foundation
import Synchronization
import Testing
@testable import TonyCore

/// A permission whose system prompt gets a fixed answer, with the rules of the real adapters:
/// the system asks only once, and a later request returns the first answer.
final class FakePermissionProvider: PermissionProvider {
    let permission: Permission
    private let current: Mutex<PermissionStatus>
    private let answer: PermissionStatus

    init(_ permission: Permission = .calendar, status: PermissionStatus = .notDetermined, answer: PermissionStatus = .granted) {
        self.permission = permission
        current = Mutex(status)
        self.answer = answer
    }

    func status() -> PermissionStatus {
        current.withLock { $0 }
    }

    func request() -> PermissionStatus {
        current.withLock { status in
            if status == .notDetermined {
                status = answer
            }
            return status
        }
    }
}

@Test(arguments: [
    (before: PermissionStatus.notDetermined, answer: PermissionStatus.granted, after: PermissionStatus.granted),
    (before: .notDetermined, answer: .denied, after: .denied),
    (before: .denied, answer: .granted, after: .denied),
    (before: .granted, answer: .denied, after: .granted),
])
func askingOnlyChangesAnUndecidedAnswer(before: PermissionStatus, answer: PermissionStatus, after: PermissionStatus) {
    let provider = FakePermissionProvider(status: before, answer: answer)

    #expect(provider.request() == after)
    #expect(provider.status() == after)
}
