import Foundation

/// A debug screen that shows what the calendar gives the planner today.
public struct CalendarDebugScreenDataModel {
    public struct Row: Identifiable, Hashable, Sendable {
        public var id: Date
        public var time: String
        public var detail: String
        public var isBusy: Bool

        public init(id: Date, time: String, detail: String, isBusy: Bool) {
            self.id = id
            self.time = time
            self.detail = detail
            self.isBusy = isBusy
        }
    }

    public var title: String
    public var access: String
    /// Nil once the user has answered the system prompt.
    public var requestAccess: ButtonDataModel?
    public var refresh: ButtonDataModel
    public var plannedAt: String?
    public var rows: [Row]
    public var onAppear: @MainActor () -> Void

    public init(
        title: String,
        access: String,
        requestAccess: ButtonDataModel?,
        refresh: ButtonDataModel,
        plannedAt: String?,
        rows: [Row],
        onAppear: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.access = access
        self.requestAccess = requestAccess
        self.refresh = refresh
        self.plannedAt = plannedAt
        self.rows = rows
        self.onAppear = onAppear
    }
}
