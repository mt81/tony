import Foundation
import TonyCore
import TonyUIModels

/// What the permission sheet shows, read from the permission manager.
@MainActor
public struct PermissionViewModel {
    private let store: PermissionStore
    private let context: PresentationContext

    public init(store: PermissionStore, context: PresentationContext) {
        self.store = store
        self.context = context
    }

    public var isPresented: Bool { Self.isPresented(store.state) }
    public var title: String { Self.title(store.state, context: context) }
    public var illustration: Illustration { Self.illustration(store.state) }
    public var explanation: String { Self.explanation(store.state, context: context) }
    public var grant: ButtonDataModel { Self.grant(store.state, context: context, store: store) }
    public var close: ButtonDataModel { Self.close(context: context, store: store) }

    public var dismiss: any Executable<Void> {
        Action(id: "permission_not_now") { [store] _ in store.notNow() }
    }

    // MARK: Reducers

    static func isPresented(_ state: PermissionState) -> Bool {
        state.isAsking
    }

    static func title(_ state: PermissionState, context: PresentationContext) -> String {
        switch state.permission {
        case .calendar, nil: localized("Plan around your events", context.locale)
        }
    }

    static func illustration(_ state: PermissionState) -> Illustration {
        switch state.permission {
        case .calendar, nil: .tony
        }
    }

    static func explanation(_ state: PermissionState, context: PresentationContext) -> String {
        let locale = context.locale
        return switch (state.permission, isRefused(state)) {
        case (.calendar, false), (nil, _):
            localized("Tony reads when you’re busy, never what your events are about, and fits your tasks in the gaps. Nothing leaves your iPhone.", locale)
        case (.calendar, true):
            localized("Calendar access is off. Turn it on in Settings and Tony will plan around your events.", locale)
        }
    }

    static func grant(_ state: PermissionState, context: PresentationContext, store: PermissionStore) -> ButtonDataModel {
        ButtonDataModel(
            // One button, titled Continue rather than Allow: the HIG's rule for a screen shown before a system prompt.
            title: isRefused(state) ? localized("Open Settings", context.locale) : localized("Continue", context.locale),
            accessibilityIdentifier: "grantPermission",
            action: Action(id: "grant_permission") { _ in Task { await store.grant() } }
        )
    }

    static func close(context: PresentationContext, store: PermissionStore) -> ButtonDataModel {
        ButtonDataModel(
            title: localized("Close", context.locale),
            systemImage: "xmark",
            role: .cancel,
            accessibilityIdentifier: "permissionClose",
            action: Action(id: "permission_not_now") { _ in store.notNow() }
        )
    }

    /// The user said no before: the system will not ask again, only Settings can change it.
    private static func isRefused(_ state: PermissionState) -> Bool {
        state.permission.flatMap { state.statuses[$0] } == .denied
    }
}
