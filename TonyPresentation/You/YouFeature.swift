import Foundation
import MemberwiseInit
import TonyCore
import TonyUIModels

/// The You tab: the user's name, their usual week, and calendar access.
public enum YouFeature: Feature {
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

    public struct State: Sendable, Equatable {
        public var name = ""
        public var routine = Routine.standard
        /// Nil until it has been read.
        public var calendarAccess: CalendarAccess?
        public var editor: Editor?
        public var hasFailed = false

        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case appeared
        case loaded(name: String, routine: Routine, calendarAccess: CalendarAccess)
        case editTapped
        case nameChanged(String)
        case dayChanged(Locale.Weekday, DayKind)
        case timeChanged(TimeField, DateComponents)
        case descriptionChanged(String)
        case descriptionSubmitted
        /// The routine read from the description; nil when it could not be read.
        case descriptionRead(Routine?)
        case editorCancelled
        case editorSaved(now: Date)
        case allowCalendarTapped
        case failed
        case alertDismissed
    }

    public enum Effect: Sendable, Equatable {
        case load
        case save(name: String, routine: Routine, now: Date)
        case requestCalendarAccess
        case read(description: String, current: Routine)
    }

    @MemberwiseInit(.public)
    public struct Environment: Sendable {
        public var repository: any Repository
        public var calendarSource: any CalendarSource
        public var coordinator: PlanCoordinator
        /// Reads the description of the week; nil when there is no model.
        public var languageService: (any LanguageService)? = nil
        public var calendar: Calendar
        public var locale: Locale
    }

    public static func reduce(_ state: inout State, _ action: Action) -> [Effect] {
        switch action {
        case .appeared:
            return [.load]
        case .loaded(let name, let routine, let calendarAccess):
            state.name = name
            state.routine = routine
            state.calendarAccess = calendarAccess
        case .editTapped:
            state.editor = Editor(name: state.name, routine: state.routine)
        case .nameChanged(let name):
            state.editor?.name = name
        case .dayChanged(let weekday, let kind):
            state.editor?.routine.homeDays.remove(weekday)
            state.editor?.routine.officeDays.remove(weekday)
            switch kind {
            case .home: state.editor?.routine.homeDays.insert(weekday)
            case .office: state.editor?.routine.officeDays.insert(weekday)
            case .off: break
            }
        case .timeChanged(let field, let time):
            let time = DateComponents(hour: time.hour ?? 0, minute: time.minute ?? 0)
            switch field {
            case .workStart: state.editor?.routine.workStart = time
            case .workEnd: state.editor?.routine.workEnd = time
            case .wakeTime: state.editor?.routine.wakeTime = time
            case .bedtime: state.editor?.routine.bedtime = time
            }
        case .descriptionChanged(let description):
            state.editor?.description = description
        case .descriptionSubmitted:
            guard let editor = state.editor, editor.reading != .inProgress else { break }
            let description = editor.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { break }
            state.editor?.reading = .inProgress
            return [.read(description: description, current: editor.routine)]
        case .descriptionRead(let routine):
            guard state.editor?.reading == .inProgress else { break }
            state.editor?.reading = routine == nil ? .notUnderstood : .filled
            if let routine {
                state.editor?.routine = routine
            }
        case .editorCancelled:
            state.editor = nil
        case .editorSaved(let now):
            guard let editor = state.editor, editor.isValid else { break }
            state.name = editor.trimmedName
            state.routine = editor.routine
            state.editor = nil
            return [.save(name: editor.trimmedName, routine: editor.routine, now: now)]
        case .allowCalendarTapped:
            return [.requestCalendarAccess]
        case .failed:
            state.hasFailed = true
        case .alertDismissed:
            state.hasFailed = false
        }
        return []
    }

    public static func run(_ effect: Effect, in environment: Environment) async -> Action? {
        let repository = environment.repository
        switch effect {
        case .load:
            break
        case .save(let name, let routine, let now):
            do {
                try await repository.save(routine)
                try await repository.save(Preference(key: Preference.userNameKey, value: name, sourceSentence: "", date: now))
            } catch {
                return .failed
            }
            await environment.coordinator.refresh()
        case .requestCalendarAccess:
            _ = await environment.calendarSource.requestAccess()
            await environment.coordinator.refresh()
        case .read(let description, let current):
            let request = RoutineWording(routine: current, calendar: environment.calendar, locale: environment.locale)
            return .descriptionRead(
                await RoutineParser.routine(
                    from: request.prompt(for: description),
                    instructions: request.instructions,
                    service: environment.languageService
                )
            )
        }
        do {
            let name = try await repository.preferences().first { $0.key == Preference.userNameKey }?.value ?? ""
            let routine = try await repository.routine() ?? .standard
            return .loaded(name: name, routine: routine, calendarAccess: await environment.calendarSource.access())
        } catch {
            return .failed
        }
    }
}

/// What the model is told to read a description of the week: the task, and the routine as it stands,
/// so that what the description does not mention stays as it is.
struct RoutineWording {
    let routine: Routine
    let calendar: Calendar
    let locale: Locale

    var instructions: String {
        ModelInstructions.routine(locale)
    }

    func prompt(for description: String) -> String {
        let weekdays = calendar.orderedWeekdays(locale: locale)
        func names(_ days: Set<Locale.Weekday>) -> String {
            let names = weekdays.filter { days.contains($0.weekday) }.map(\.name)
            return names.isEmpty ? localized("none", locale) : names.formatted(.list(type: .and, width: .narrow).locale(locale))
        }
        func time(_ components: DateComponents) -> String {
            String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
        }
        return [
            localized("Current routine:", locale),
            localized("Home days: \(names(routine.homeDays))", locale),
            localized("Office days: \(names(routine.officeDays))", locale),
            localized("Work from \(time(routine.workStart)) to \(time(routine.workEnd))", locale),
            localized("Up at \(time(routine.wakeTime)), bed at \(time(routine.bedtime))", locale),
            localized("Description: \(description)", locale),
        ].joined(separator: "\n")
    }
}

extension DateComponents {
    fileprivate var minutesIntoDay: Int {
        (hour ?? 0) * 60 + (minute ?? 0)
    }
}
