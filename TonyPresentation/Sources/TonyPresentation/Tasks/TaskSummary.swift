import Foundation
import TonyCore

/// The two lines of text and the chip of a task row.
struct TaskSummary: Equatable {
    let subtitle: String
    let status: String
    let isNeglected: Bool

    init(task: TonyTask, completions: [Completion], context: PresentationContext) {
        let locale = context.locale
        let stepNames = task.steps.count > 1 ? task.steps.map { $0.name.lowercased(with: locale) } : []
        let steps = stepNames.isEmpty ? [] : [stepNames.formatted(.list(type: .and, width: .narrow).locale(locale))]
        subtitle = ([Self.cadenceText(for: task, context: context)] + steps).joined(separator: " · ")

        isNeglected = task.neglect(completions: completions, on: context.now, calendar: context.calendar) > 0
        status = Self.statusText(for: task, completions: completions, isNeglected: isNeglected, context: context)
    }

    private static func cadenceText(for task: TonyTask, context: PresentationContext) -> String {
        let locale = context.locale
        switch task.cadence {
        case .afterCompletion(let days):
            return localized("Every \(days) days after last time", locale)
        case .weekdays(let weekdays):
            let names = context.calendar.orderedWeekdays(locale: locale)
                .filter { weekdays.contains($0.weekday) }
                .map(\.name)
            return localized("Every \(names.formatted(.list(type: .and).locale(locale)))", locale)
        case .timesPerWeek(let times):
            return localized("\(times) times a week", locale)
        case nil:
            guard let deadline = task.mustHappenBy else {
                return localized("No date", locale)
            }
            let day = deadline.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
            return localized("By \(day)", locale)
        }
    }

    private static func statusText(
        for task: TonyTask,
        completions: [Completion],
        isNeglected: Bool,
        context: PresentationContext
    ) -> String {
        let (now, calendar, locale) = (context.now, context.calendar, context.locale)
        if let progress = task.weeklyQuotaProgress(completions: completions, on: now, calendar: calendar) {
            let done = progress.done.formatted(.number.locale(locale))
            let target = progress.target.formatted(.number.locale(locale))
            return "\(done) / \(target)"
        }
        if isNeglected {
            return localized("Due", locale)
        }
        if task.isDue(completions: completions, on: now, calendar: calendar) {
            if task.cadence == nil, let deadline = task.mustHappenBy {
                var formatStyle = Date.FormatStyle.dateTime.weekday(.abbreviated).locale(locale)
                formatStyle.timeZone = calendar.timeZone
                return deadline.formatted(formatStyle)
            }
            return task.cadence == nil ? localized("Someday", locale) : localized("Today", locale)
        }
        guard
            let dueDay = task.dueDay(completions: completions, on: now, calendar: calendar),
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: dueDay).day
        else {
            return localized("Done", locale)
        }
        return localized("In \(days) days", locale)
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
