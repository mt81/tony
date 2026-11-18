import Foundation
import Observation
import TonyCore

/// Holds the You tab's state and is the only thing that changes it.
@MainActor
@Observable
public final class YouStore {
    public private(set) var state = YouState()

    @ObservationIgnored private let repository: any Repository
    @ObservationIgnored private let calendarSource: any CalendarSource
    @ObservationIgnored private let coordinator: PlanCoordinator
    /// Reads the description of the week; nil when there is no model.
    @ObservationIgnored private let languageService: (any LanguageService)?
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let locale: Locale

    public init(
        repository: any Repository,
        calendarSource: any CalendarSource,
        coordinator: PlanCoordinator,
        languageService: (any LanguageService)? = nil,
        calendar: Calendar,
        locale: Locale
    ) {
        self.repository = repository
        self.calendarSource = calendarSource
        self.coordinator = coordinator
        self.languageService = languageService
        self.calendar = calendar
        self.locale = locale
    }

    public func load() async {
        do {
            let name = try await repository.preferences().first { $0.key == Preference.userNameKey }?.value ?? ""
            let routine = try await repository.routine() ?? .standard
            let calendarAccess = await calendarSource.access()
            state.name = name
            state.routine = routine
            state.calendarAccess = calendarAccess
        } catch {
            state.hasFailed = true
        }
    }

    public func startEditing() {
        state.editor = YouState.Editor(name: state.name, routine: state.routine)
    }

    public func changeName(_ name: String) {
        state.editor?.name = name
    }

    public func changeDay(_ weekday: Locale.Weekday, to kind: YouState.DayKind) {
        state.editor?.routine.homeDays.remove(weekday)
        state.editor?.routine.officeDays.remove(weekday)
        switch kind {
        case .home: state.editor?.routine.homeDays.insert(weekday)
        case .office: state.editor?.routine.officeDays.insert(weekday)
        case .off: break
        }
    }

    public func changeTime(_ field: YouState.TimeField, to time: DateComponents) {
        let time = DateComponents(hour: time.hour ?? 0, minute: time.minute ?? 0)
        switch field {
        case .workStart: state.editor?.routine.workStart = time
        case .workEnd: state.editor?.routine.workEnd = time
        case .wakeTime: state.editor?.routine.wakeTime = time
        case .bedtime: state.editor?.routine.bedtime = time
        }
    }

    public func changeDescription(_ description: String) {
        state.editor?.description = description
    }

    /// Has the model read the description into the form. The form is not saved.
    public func readDescription() async {
        guard let editor = state.editor, editor.reading != .inProgress else { return }
        let description = editor.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { return }
        state.editor?.reading = .inProgress
        let request = RoutineWording(routine: editor.routine, calendar: calendar, locale: locale)
        let routine = await RoutineParser.routine(
            from: request.prompt(for: description),
            instructions: request.instructions,
            service: languageService
        )
        guard state.editor?.reading == .inProgress else { return }
        state.editor?.reading = routine == nil ? .notUnderstood : .filled
        if let routine {
            state.editor?.routine = routine
        }
    }

    public func cancelEditing() {
        state.editor = nil
    }

    public func save(now: Date) async {
        guard let editor = state.editor, editor.isValid else { return }
        state.name = editor.trimmedName
        state.routine = editor.routine
        state.editor = nil
        do {
            try await repository.save(editor.routine)
            try await repository.save(Preference(key: Preference.userNameKey, value: editor.trimmedName, sourceSentence: "", date: now))
        } catch {
            state.hasFailed = true
            return
        }
        await coordinator.refresh()
        await load()
    }

    public func allowCalendar() async {
        _ = await calendarSource.requestAccess()
        await coordinator.refresh()
        await load()
    }

    public func dismissAlert() {
        state.hasFailed = false
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
