import Foundation
import TonyCore

/// The You tab: the user's name, their usual week, and calendar access.
public struct YouState: Sendable, Equatable {
    public enum DayKind: String, Sendable, CaseIterable {
        case home
        case office
        case off
    }

    /// What happened to the description of the week.
    public enum Reading: Sendable, Equatable {
        case none
        case inProgress
        case filled
        case notUnderstood
    }

    public enum TimeField: Sendable, Equatable {
        case workStart
        case workEnd
        case wakeTime
        case bedtime
    }

    /// The form: a draft of the name and the routine, saved together.
    public struct Editor: Sendable, Equatable {
        public var name: String
        public var routine: Routine
        /// The week in the user's own words, which the model reads into the form.
        public var description = ""
        public var reading = Reading.none

        public var trimmedName: String {
            name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// Work has to end after it starts, or the day has no work hours to plan around.
        public var isValid: Bool {
            routine.workStart.minutesIntoDay < routine.workEnd.minutesIntoDay
        }

        public func kind(of weekday: Locale.Weekday) -> DayKind {
            if routine.officeDays.contains(weekday) { .office } else if routine.homeDays.contains(weekday) { .home } else { .off }
        }
    }

    public var name = ""
    public var routine = Routine.standard
    /// Nil until it has been read.
    public var calendarAccess: CalendarAccess?
    public var editor: Editor?
    public var hasFailed = false

    public init() {}
}

extension DateComponents {
    fileprivate var minutesIntoDay: Int {
        (hour ?? 0) * 60 + (minute ?? 0)
    }
}
