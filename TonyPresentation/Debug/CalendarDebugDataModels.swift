import Foundation
import MemberwiseInit
import TonyUIModels

/// A debug screen that shows what the calendar gives the planner today.
@MemberwiseInit(.public)
public struct CalendarDebugScreenDataModel {
    @MemberwiseInit(.public)
    public struct Row: Identifiable, Hashable, Sendable {
        public var id: Date
        public var time: String
        public var detail: String
        public var isBusy: Bool
    }

    public var title: String
    public var access: String
    /// Nil once the user has answered the system prompt.
    public var requestAccess: ButtonDataModel?
    public var refresh: ButtonDataModel
    public var plannedAt: String?
    public var rows: [Row]
    public var onAppear: any Executable<Void>
}
