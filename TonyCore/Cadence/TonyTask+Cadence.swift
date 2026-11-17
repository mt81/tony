import Foundation

public struct WeeklyQuotaProgress: Codable, Sendable, Hashable {
    public var done: Int
    public var target: Int
    /// Days left in the week, today included.
    public var daysLeft: Int
}

extension TonyTask {
    public func isDue(completions: [Completion], on day: Date, calendar: Calendar) -> Bool {
        if case .timesPerWeek = cadence {
            guard let progress = weeklyQuotaProgress(completions: completions, on: day, calendar: calendar) else {
                return false
            }
            return progress.done < progress.target
        }
        guard let dueDay = dueDay(completions: completions, on: day, calendar: calendar) else {
            return false
        }
        return calendar.startOfDay(for: day) >= dueDay
    }

    /// Zero until the task is overdue, then `e^x - 1` where x is the overdue time as a fraction of the cadence period.
    public func neglect(completions: [Completion], on day: Date, calendar: Calendar) -> Double {
        guard
            let periodInDays,
            let dueDay = dueDay(completions: completions, on: day, calendar: calendar),
            let daysOverdue = calendar.dateComponents([.day], from: dueDay, to: calendar.startOfDay(for: day)).day,
            daysOverdue > 0
        else {
            return 0
        }
        return expm1(Double(daysOverdue) / periodInDays)
    }

    public func weeklyQuotaProgress(completions: [Completion], on day: Date, calendar: Calendar) -> WeeklyQuotaProgress? {
        guard
            case .timesPerWeek(let target) = cadence,
            target > 0,
            let week = calendar.dateInterval(of: .weekOfYear, for: day),
            let daysLeft = calendar.dateComponents([.day], from: calendar.startOfDay(for: day), to: week.end).day
        else {
            return nil
        }
        let done = doneDates(completions: completions, upTo: day, calendar: calendar)
            .count { $0 >= week.start }
        return WeeklyQuotaProgress(done: done, target: target, daysLeft: daysLeft)
    }

    private var periodInDays: Double? {
        switch cadence {
        case .afterCompletion(let days) where days > 0:
            Double(days)
        case .weekdays(let weekdays) where !weekdays.isEmpty:
            7 / Double(weekdays.count)
        case .timesPerWeek(let target) where target > 0:
            7 / Double(target)
        default:
            nil
        }
    }

    /// The first day the task counts as due, given what was done up to `day`; nil when it will not come due again.
    /// For a weekly quota it is the day a full week has passed without a session, which only drives neglect.
    public func dueDay(completions: [Completion], on day: Date, calendar: Calendar) -> Date? {
        let lastDone = doneDates(completions: completions, upTo: day, calendar: calendar).max()
        let lastDoneDay = lastDone.map { calendar.startOfDay(for: $0) }
        let createdDay = calendar.startOfDay(for: createdAt)

        switch cadence {
        case nil:
            return lastDoneDay == nil ? createdDay : nil
        case .afterCompletion(let days) where days > 0:
            guard let lastDoneDay else { return createdDay }
            return calendar.date(byAdding: .day, value: days, to: lastDoneDay)
        case .weekdays(let weekdays) where !weekdays.isEmpty:
            let firstCandidate = lastDoneDay.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) } ?? createdDay
            return (0..<7)
                .compactMap { calendar.date(byAdding: .day, value: $0, to: firstCandidate) }
                .first { weekdays.contains(calendar.localeWeekday(of: $0)) }
        case .timesPerWeek(let target) where target > 0:
            return calendar.date(byAdding: .day, value: 7, to: lastDoneDay ?? createdDay)
        default:
            return nil
        }
    }

    private func doneDates(completions: [Completion], upTo day: Date, calendar: Calendar) -> [Date] {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) else {
            return []
        }
        return completions
            .filter { $0.taskID == id && $0.stepID == nil && $0.outcome == .done && $0.date < nextDay }
            .map(\.date)
    }
}

extension Calendar {
    func localeWeekday(of date: Date) -> Locale.Weekday {
        let weekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        return weekdays[(component(.weekday, from: date) + 6) % 7]
    }
}
