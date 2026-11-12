import Foundation

extension DayContext {
    /// Events closer than this are shown and planned around as one busy block.
    public static let mergeGap: TimeInterval = 15 * 60

    public init(
        routine: Routine,
        busyIntervals: [DateInterval],
        status: DayStatus,
        conditions: DayConditions,
        day: Date,
        calendar: Calendar
    ) {
        let startOfDay = calendar.startOfDay(for: day)
        let dayInterval = calendar.dateInterval(of: .day, for: day) ?? DateInterval(start: startOfDay, duration: 86_400)
        let weekday = calendar.localeWeekday(of: startOfDay)
        let isOfficeDay = routine.officeDays.contains(weekday)
        let isWorkingDay = isOfficeDay || routine.homeDays.contains(weekday)

        let location: Location =
            if status == .travelling { .away } else if isOfficeDay { .office } else { .home }
        let windowStarts = Self.windowStarts(routine: routine, dayInterval: dayInterval, calendar: calendar)

        func freeBlocks(from start: Date, to end: Date) -> [Block] {
            let innerStarts = windowStarts.map(\.start).filter { $0 > start && $0 < end }
            let cuts = [start] + innerStarts + [end]
            return zip(cuts, cuts.dropFirst())
                .filter { $0 < $1 }
                .map { blockStart, blockEnd in
                    let window = Self.window(at: blockStart, in: windowStarts)
                    let availability: Availability = isWorkingDay && window == .workday ? .partiallyAvailable : .free
                    return Block(
                        interval: DateInterval(start: blockStart, end: blockEnd),
                        location: location,
                        availability: availability,
                        window: window
                    )
                }
        }

        var blocks: [Block] = []
        var cursor = dayInterval.start
        for busy in Self.mergedBusyBlocks(busyIntervals, in: dayInterval) {
            blocks += freeBlocks(from: cursor, to: busy.interval.start)
            blocks.append(
                Block(
                    interval: busy.interval,
                    location: location,
                    availability: .busy,
                    window: Self.window(at: busy.interval.start, in: windowStarts),
                    eventCount: busy.eventCount
                )
            )
            cursor = busy.interval.end
        }
        blocks += freeBlocks(from: cursor, to: dayInterval.end)

        let capacity: Capacity =
            switch status {
            case .normal: .full
            case .sick, .travelling: .reduced
            case .offDay: .off
            }

        self.init(blocks: blocks, capacity: capacity, conditions: conditions)
    }

    private typealias BusyBlock = (interval: DateInterval, eventCount: Int)
    private typealias WindowStart = (start: Date, window: Window)

    private static func mergedBusyBlocks(_ busyIntervals: [DateInterval], in dayInterval: DateInterval) -> [BusyBlock] {
        busyIntervals
            .compactMap { $0.intersection(with: dayInterval) }
            .filter { $0.duration > 0 }
            .sorted { $0.start < $1.start }
            .reduce(into: [BusyBlock]()) { merged, interval in
                guard let last = merged.last, interval.start.timeIntervalSince(last.interval.end) < mergeGap else {
                    merged.append((interval, 1))
                    return
                }
                let end = max(last.interval.end, interval.end)
                merged[merged.count - 1] = (DateInterval(start: last.interval.start, end: end), last.eventCount + 1)
            }
    }

    private static func windowStarts(routine: Routine, dayInterval: DateInterval, calendar: Calendar) -> [WindowStart] {
        func time(_ components: DateComponents) -> Date {
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0
            let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayInterval.start)
            return min(max(date ?? dayInterval.start, dayInterval.start), dayInterval.end)
        }
        let wake = time(routine.wakeTime)
        let workStart = max(time(routine.workStart), wake)
        let workEnd = max(time(routine.workEnd), workStart)
        let bedtime = time(routine.bedtime)
        // A bedtime after midnight belongs to the next day, so the evening runs to the end of this one.
        let nightStart = bedtime > workEnd ? bedtime : dayInterval.end

        return [
            (dayInterval.start, .night),
            (wake, .morning),
            (workStart, .workday),
            (workEnd, .evening),
            (nightStart, .night),
        ]
    }

    private static func window(at date: Date, in windowStarts: [WindowStart]) -> Window {
        windowStarts.last { $0.start <= date }?.window ?? .night
    }
}
