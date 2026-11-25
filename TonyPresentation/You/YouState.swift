import Foundation
import Observation
import TonyCore

/// The You tab: the user's name, their usual week, and calendar access. Only `YouStore` writes to it.
@MainActor
@Observable
final class YouState {
    enum DayKind: String, Sendable, CaseIterable {
        case home
        case office
        case off
    }

    /// What happened to the description of the week.
    enum Reading: Sendable, Equatable {
        case none
        case inProgress
        case filled
        case notUnderstood
    }

    enum TimeField: Sendable, Equatable {
        case workStart
        case workEnd
        case wakeTime
        case bedtime
    }

    /// The form: a draft of the name and the routine, saved together.
    struct Editor: Sendable, Equatable {
        var name: String
        var routine: Routine
        /// The week in the user's own words, which the model reads into the form.
        var description = ""
        var reading = Reading.none

        var trimmedName: String {
            name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// Work has to end after it starts, or the day has no work hours to plan around.
        var isValid: Bool {
            routine.workStart.minutesIntoDay < routine.workEnd.minutesIntoDay
        }

        func kind(of weekday: Locale.Weekday) -> DayKind {
            if routine.officeDays.contains(weekday) { .office } else if routine.homeDays.contains(weekday) { .home } else { .off }
        }
    }

    var name = ""
    var routine = Routine.standard
    /// Nil until it has been read.
    var calendarAccess: PermissionStatus?
    var editor: Editor?
    var hasFailed = false
}

extension DateComponents {
    fileprivate var minutesIntoDay: Int {
        (hour ?? 0) * 60 + (minute ?? 0)
    }
}
