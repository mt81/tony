import Foundation
import TonyCore

/// The two lines of text and the chip of a task row.
struct TaskSummary {
    let subtitle: String
    let status: String
    let isNeglected: Bool

    init(task: TonyTask, completions: [Completion], now: Date, calendar: Calendar, locale: Locale) {
        let stepNames = task.steps.count > 1 ? task.steps.map { $0.name.lowercased(with: locale) } : []
        let parts = [Self.cadenceText(for: task, calendar: calendar, locale: locale)] + (stepNames.isEmpty ? [] : [stepNames.formatted(.list(type: .and, width: .narrow).locale(locale))])
        subtitle = parts.joined(separator: " · ")

        let neglect = task.neglect(completions: completions, on: now, calendar: calendar)
        isNeglected = neglect > 0
        status = Self.statusText(for: task, completions: completions, isNeglected: neglect > 0, now: now, calendar: calendar, locale: locale)
    }

    private static func cadenceText(for task: TonyTask, calendar: Calendar, locale: Locale) -> String {
        switch task.cadence {
        case .afterCompletion(let days):
            return String(localized: "Every \(days) days after last time", locale: locale)
        case .weekdays(let weekdays):
            let names = calendar.orderedWeekdays(locale: locale)
                .filter { weekdays.contains($0.weekday) }
                .map(\.name)
            return String(localized: "Every \(names.formatted(.list(type: .and).locale(locale)))", locale: locale)
        case .timesPerWeek(let times):
            return String(localized: "\(times) times a week", locale: locale)
        case nil:
            guard let deadline = task.mustHappenBy else {
                return String(localized: "No date", locale: locale)
            }
            let day = deadline.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
            return String(localized: "By \(day)", locale: locale)
        }
    }

    private static func statusText(
        for task: TonyTask,
        completions: [Completion],
        isNeglected: Bool,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        if let progress = task.weeklyQuotaProgress(completions: completions, on: now, calendar: calendar) {
            let done = progress.done.formatted(.number.locale(locale))
            let target = progress.target.formatted(.number.locale(locale))
            return "\(done) / \(target)"
        }
        if isNeglected {
            return String(localized: "Due", locale: locale)
        }
        if task.isDue(completions: completions, on: now, calendar: calendar) {
            if task.cadence == nil, let deadline = task.mustHappenBy {
                return deadline.formatted(.dateTime.weekday(.abbreviated).locale(locale))
            }
            return task.cadence == nil ? String(localized: "Someday", locale: locale) : String(localized: "Today", locale: locale)
        }
        guard
            let dueDay = task.dueDay(completions: completions, on: now, calendar: calendar),
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: dueDay).day
        else {
            return String(localized: "Done", locale: locale)
        }
        return String(localized: "In \(days) days", locale: locale)
    }
}

extension Calendar {
    /// The seven weekdays in this calendar's order, with their names in the given locale.
    func orderedWeekdays(locale: Locale) -> [(weekday: Locale.Weekday, name: String)] {
        var localised = self
        localised.locale = locale
        let weekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        return (0..<7).map { offset in
            let index = (firstWeekday - 1 + offset) % 7
            return (weekdays[index], localised.standaloneWeekdaySymbols[index])
        }
    }
}
