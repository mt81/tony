import Foundation
import Observation
import TonyCore

/// The Today tab: the day's plan from the coordinator, its wording, and the task being added. Only `TodayStore` writes to it.
@MainActor
@Observable
final class TodayState {
    /// The model's wording of one plan. It is shown for as long as that plan is the one on screen.
    struct WordedBriefing: Sendable, Equatable {
        var plan: DayPlan
        var text: String
    }

    enum Failure: Sendable, Equatable {
        case answer
        case task
    }

    var planned: PlannedDay?
    var briefing: WordedBriefing?
    /// The name entered in the You tab; nil when there is none.
    var userName: String?
    /// Nil until it has been read.
    var calendarAccess: PermissionStatus?
    var editor: TaskEditor.State?
    var failure: Failure?
}
