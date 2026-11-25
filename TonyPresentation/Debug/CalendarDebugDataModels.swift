import Foundation
import MemberwiseInit
import TonyUIModels

/// A debug screen that shows what the calendar and the weather give the planner today.
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
    public var weather: String
    /// Saves a sample city for the weather, or clears it.
    public var places: [ButtonDataModel]
    /// Nil once the user has answered the system prompt.
    public var requestAccess: ButtonDataModel?
    public var refresh: ButtonDataModel
    public var plannedAt: String?
    public var rows: [Row]
    public var onAppear: any Executable<Void>
}

extension CalendarDebugScreenDataModel: Equatable {
    public static func == (lhs: CalendarDebugScreenDataModel, rhs: CalendarDebugScreenDataModel) -> Bool {
        lhs.title == rhs.title
            && lhs.access == rhs.access
            && lhs.weather == rhs.weather
            && lhs.places == rhs.places
            && lhs.requestAccess == rhs.requestAccess
            && lhs.refresh == rhs.refresh
            && lhs.plannedAt == rhs.plannedAt
            && lhs.rows == rhs.rows
            && lhs.onAppear.isEqual(to: rhs.onAppear)
    }
}
