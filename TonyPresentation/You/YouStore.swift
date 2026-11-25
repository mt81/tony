import Foundation
import TonyCore

/// Holds the You tab's state and is the only thing that changes it.
@MainActor
public final class YouStore {
    let state = YouState()

    private let repository: any Repository
    private let permissions: PermissionStore
    private let coordinator: PlanCoordinator
    /// Reads the description of the week; nil when there is no model.
    private let languageService: (any LanguageService)?
    private let calendar: Calendar
    private let locale: Locale
    private let now: @Sendable () -> Date

    public init(
        repository: any Repository,
        permissions: PermissionStore,
        coordinator: PlanCoordinator,
        languageService: (any LanguageService)? = nil,
        calendar: Calendar,
        locale: Locale,
        now: @escaping @Sendable () -> Date
    ) {
        self.repository = repository
        self.permissions = permissions
        self.coordinator = coordinator
        self.languageService = languageService
        self.calendar = calendar
        self.locale = locale
        self.now = now
    }

    func load() async {
        do {
            let name = try await repository.preferences().first { $0.key == Preference.userNameKey }?.value ?? ""
            let routine = try await repository.routine() ?? .standard
            let calendarAccess = await permissions.status(of: .calendar)
            state.name = name
            state.routine = routine
            state.calendarAccess = calendarAccess
        } catch {
            state.hasFailed = true
        }
    }

    func startEditing() {
        state.editor = YouState.Editor(name: state.name, routine: state.routine)
    }

    func changeName(_ name: String) {
        state.editor?.name = name
    }

    func changeDay(_ weekday: Locale.Weekday, to kind: YouState.DayKind) {
        state.editor?.routine.homeDays.remove(weekday)
        state.editor?.routine.officeDays.remove(weekday)
        switch kind {
        case .home: state.editor?.routine.homeDays.insert(weekday)
        case .office: state.editor?.routine.officeDays.insert(weekday)
        case .off: break
        }
    }

    func changeTime(_ field: YouState.TimeField, to date: Date) {
        let picked = calendar.dateComponents([.hour, .minute], from: date)
        let time = DateComponents(hour: picked.hour ?? 0, minute: picked.minute ?? 0)
        switch field {
        case .workStart: state.editor?.routine.workStart = time
        case .workEnd: state.editor?.routine.workEnd = time
        case .wakeTime: state.editor?.routine.wakeTime = time
        case .bedtime: state.editor?.routine.bedtime = time
        }
    }

    func changeDescription(_ description: String) {
        state.editor?.description = description
    }

    /// Has the model read the description into the form. The form is not saved.
    func readDescription() async {
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
        if var routine {
            routine.place = editor.routine.place
            state.editor?.routine = routine
        }
    }

    func cancelEditing() {
        state.editor = nil
    }

    func save() async {
        guard let editor = state.editor, editor.isValid else { return }
        state.name = editor.trimmedName
        state.routine = editor.routine
        state.editor = nil
        do {
            try await repository.save(editor.routine)
            try await repository.save(Preference(key: Preference.userNameKey, value: editor.trimmedName, sourceSentence: "", date: now()))
        } catch {
            state.hasFailed = true
            return
        }
        await coordinator.refresh()
        await load()
    }

    func allowCalendar() async {
        _ = await permissions.request(.calendar)
        await coordinator.refresh()
        await load()
    }

    func dismissAlert() {
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
