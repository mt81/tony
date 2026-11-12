import Foundation
import Testing
@testable import TonyCore

enum Fixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Day 2 is Monday 2 November 2026, so days 2 to 8 are one Monday-to-Sunday week.
    static func november(_ day: Int, hour: Int = 0, minute: Int = 0) throws -> Date {
        let components = DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)
        return try #require(calendar.date(from: components))
    }

    static func identifier(_ number: Int) throws -> UUID {
        let suffix = String(format: "%012d", number)
        return try #require(UUID(uuidString: "00000000-0000-0000-0000-\(suffix)"))
    }

    static func laundry() throws -> TonyTask {
        TonyTask(
            id: try identifier(1),
            name: "Laundry",
            icon: "washer",
            kind: .recurring,
            rank: 0,
            cadence: .afterCompletion(days: 5),
            requirements: Requirements(location: .home),
            steps: [
                Step(id: try identifier(2), name: "Wash", mode: .background, duration: 45 * 60),
                Step(id: try identifier(3), name: "Dry", mode: .background, duration: 60 * 60, minimumGapToNextStep: 30 * 60),
                Step(
                    id: try identifier(4),
                    name: "Fold",
                    mode: .active,
                    duration: 15 * 60,
                    requirements: Requirements(availability: .free, windows: [.evening])
                ),
            ],
            mustHappenBy: try november(8),
            createdAt: try november(1)
        )
    }

    static func routine() -> Routine {
        Routine(
            homeDays: [.monday, .friday],
            officeDays: [.tuesday, .wednesday, .thursday],
            workStart: DateComponents(hour: 9, minute: 0),
            workEnd: DateComponents(hour: 17, minute: 0),
            wakeTime: DateComponents(hour: 7, minute: 0),
            bedtime: DateComponents(hour: 23, minute: 0)
        )
    }
}
