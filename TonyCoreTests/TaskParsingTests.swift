import Foundation
import Testing
@testable import TonyCore

struct SentenceCase: Sendable, CustomTestStringConvertible {
    var sentence: String
    var language: String
    var name: String
    var cadence: Cadence?

    var testDescription: String { sentence }

    init(_ sentence: String, _ language: String, _ name: String, _ cadence: Cadence?) {
        self.sentence = sentence
        self.language = language
        self.name = name
        self.cadence = cadence
    }
}

@Test(arguments: [
    SentenceCase("Water the plants every 5 days", "en", "Water the plants", .every(5, .day)),
    SentenceCase("water the plants every five days", "en", "Water the plants", .every(5, .day)),
    SentenceCase("Every other day, stretch", "en", "Stretch", .every(2, .day)),
    SentenceCase("Laundry every week", "en", "Laundry", .every(1, .week)),
    SentenceCase("Change the bed sheets every 2 weeks", "en", "Change the bed sheets", .every(2, .week)),
    SentenceCase("Take supplements daily", "en", "Take supplements", .every(1, .day)),
    SentenceCase("Vacuum every other week", "en", "Vacuum", .every(2, .week)),
    SentenceCase("Pay the rent every month", "en", "Pay the rent", .every(1, .month)),
    SentenceCase("Descale the kettle every 3 months", "en", "Descale the kettle", .every(3, .month)),
    SentenceCase("Service the boiler yearly", "en", "Service the boiler", .every(1, .year)),
    SentenceCase("Stand-up every weekday", "en", "Stand-up", .weekdays([.monday, .tuesday, .wednesday, .thursday, .friday])),
    SentenceCase("Take out the trash every Tuesday", "en", "Take out the trash", .weekdays([.tuesday])),
    SentenceCase("Meal prep on Sundays and Wednesdays", "en", "Meal prep", .weekdays([.sunday, .wednesday])),
    SentenceCase("Go to the gym 3 times a week", "en", "Go to the gym", .timesPerWeek(3)),
    SentenceCase("Run twice a week", "en", "Run", .timesPerWeek(2)),
    SentenceCase("Renew my passport", "en", "Renew my passport", nil),
    SentenceCase("Water the plants every 900 days", "en", "Water the plants every 900 days", nil),
    SentenceCase("Arroser les plantes tous les 5 jours", "fr", "Arroser les plantes", .every(5, .day)),
    SentenceCase("arroser les plantes tous les cinq jours", "fr", "Arroser les plantes", .every(5, .day)),
    SentenceCase("Lessive chaque semaine", "fr", "Lessive", .every(1, .week)),
    SentenceCase("Changer les draps toutes les 2 semaines", "fr", "Changer les draps", .every(2, .week)),
    SentenceCase("Prendre les compléments tous les jours", "fr", "Prendre les compléments", .every(1, .day)),
    SentenceCase("Payer le loyer tous les mois", "fr", "Payer le loyer", .every(1, .month)),
    SentenceCase("Détartrer la bouilloire tous les 3 mois", "fr", "Détartrer la bouilloire", .every(3, .month)),
    SentenceCase("Réviser la chaudière chaque année", "fr", "Réviser la chaudière", .every(1, .year)),
    SentenceCase("Point d'équipe en semaine", "fr", "Point d'équipe", .weekdays([.monday, .tuesday, .wednesday, .thursday, .friday])),
    SentenceCase("Sortir les poubelles chaque mardi", "fr", "Sortir les poubelles", .weekdays([.tuesday])),
    SentenceCase("Préparer les repas le dimanche et le mercredi", "fr", "Préparer les repas", .weekdays([.sunday, .wednesday])),
    SentenceCase("Aller à la salle de sport 3 fois par semaine", "fr", "Aller à la salle de sport", .timesPerWeek(3)),
    SentenceCase("Courir deux fois par semaine", "fr", "Courir", .timesPerWeek(2)),
    SentenceCase("Renouveler mon passeport", "fr", "Renouveler mon passeport", nil),
])
func theRulesReadTheCadenceAndLeaveTheName(_ sentenceCase: SentenceCase) {
    let draft = CadenceRules.draft(from: sentenceCase.sentence, locale: Locale(identifier: sentenceCase.language))

    #expect(draft == TaskDraft(name: sentenceCase.name, cadence: sentenceCase.cadence))
}

@Test func theKindFollowsTheCadence() {
    #expect(TaskDraft(name: "Gym", cadence: .timesPerWeek(3)).kind == .goal)
    #expect(TaskDraft(name: "Plants", cadence: .every(5, .day)).kind == .recurring)
    #expect(TaskDraft(name: "Trash", cadence: .weekdays([.tuesday])).kind == .recurring)
    #expect(TaskDraft(name: "Passport", cadence: nil).kind == .oneTime)
}

// MARK: With the model

private struct FixedService: LanguageService {
    var reading: TaskReading?
    var routine: Routine?

    func briefing(instructions: String, plan: String) async throws -> String { throw CocoaError(.featureUnsupported) }

    func taskReading(instructions: String, sentence: String) async throws -> TaskReading {
        guard let reading else { throw CocoaError(.featureUnsupported) }
        return reading
    }

    func routine(instructions: String, description: String) async throws -> Routine {
        guard let routine else { throw CocoaError(.featureUnsupported) }
        return routine
    }
}

/// Today is Thursday 19 November 2026.
private func draft(_ sentence: String, model: TaskReading?) async throws -> TaskDraft {
    await TaskSentenceParser.draft(
        from: sentence,
        locale: Locale(identifier: "en"),
        instructions: "",
        service: FixedService(reading: model),
        now: try Fixtures.november(19, hour: 9),
        calendar: Fixtures.calendar
    )
}

@Test func theRulesReadTheCadenceAndTheModelTheRest() async throws {
    let reading = TaskReading(
        name: "Water the plants",
        icon: "🪴",
        cadence: .timesPerWeek(5),
        requirements: Requirements(location: .home, windows: [.morning], avoidedWeather: [.rain], costsMoney: true)
    )

    #expect(try await draft("Water the plants every 5 days", model: reading) == TaskDraft(
        name: "Water the plants",
        icon: "🪴",
        cadence: .every(5, .day),
        requirements: Requirements(location: .home, windows: [.morning], avoidedWeather: [.rain])
    ))
}

@Test func theModelReadsWhatTheRulesDoNot() async throws {
    let reading = TaskReading(name: "water the plants", cadence: .every(3, .day))

    #expect(try await draft("Water the plants every couple of days or so", model: reading) == TaskDraft(name: "water the plants", cadence: .every(3, .day)))
}

@Test func aFixedScheduleStartsOnTheFirstDayThatMatches() async throws {
    let reading = TaskReading(name: "Pay the rent", cadence: .every(1, .month), scheduleStart: DateComponents(day: 1))
    let firstOfDecember = try Fixtures.november(31)

    #expect(try await draft("Pay the rent on the 1st, every month", model: reading).cadence == .interval(
        Cadence.Interval(count: 1, unit: .month),
        countedFrom: .schedule(from: firstOfDecember)
    ))
}

@Test func aFixedScheduleWithoutADayStartsToday() async throws {
    let reading = TaskReading(name: "Vacuum", cadence: .every(2, .week), scheduleStart: DateComponents())

    #expect(try await draft("Vacuum every 2 weeks on a fixed schedule", model: reading).cadence == .interval(
        Cadence.Interval(count: 2, unit: .week),
        countedFrom: .schedule(from: try Fixtures.november(19))
    ))
}

@Test func theDeadlineIsTheNextDayWithThatDate() async throws {
    let thisYear = TaskReading(name: "Renew my passport", deadline: DateComponents(month: 12, day: 15))
    let nextYear = TaskReading(name: "Renew my passport", deadline: DateComponents(month: 3, day: 3))
    let nextMarch = try #require(Fixtures.calendar.date(from: DateComponents(year: 2027, month: 3, day: 3)))

    #expect(try await draft("Renew my passport by 15 December", model: thisYear).deadline == (try Fixtures.november(45)))
    #expect(try await draft("Renew my passport by 3 March", model: nextYear).deadline == nextMarch)
}

@Test func subtasksAreKeptOnlyForATaskOfSeveralSensibleSteps() async throws {
    let wash = StepTemplate(name: "Wash", mode: .active, duration: 10 * 60)
    let fold = StepTemplate(name: "Fold", mode: .active, duration: 15 * 60)
    let unnamed = StepTemplate(name: " ", mode: .active, duration: 10 * 60)
    let endless = StepTemplate(name: "Dry", mode: .active, duration: 24 * 3600)
    func subtasks(_ steps: [StepTemplate]) async throws -> [StepTemplate] {
        try await draft("Do the laundry", model: TaskReading(name: "Do the laundry", subtasks: steps)).subtasks
    }

    #expect(try await subtasks([wash, unnamed, endless, fold]) == [wash, fold])
    #expect(try await subtasks([wash, endless]) == [])
}

@Test(arguments: ["leaf", "", "🧺 laundry"])
func theIconIsOneEmoji(icon: String) async throws {
    let read = try await draft("Do the laundry", model: TaskReading(name: "Do the laundry", icon: icon))

    #expect(read.icon == (icon.hasPrefix("🧺") ? "🧺" : nil))
}

@Test(arguments: [
    TaskReading(name: "Feed the cat", cadence: .every(3, .day)),
    TaskReading(name: "", cadence: .every(3, .day)),
    TaskReading(name: "Water the plants", cadence: .every(0, .day)),
    TaskReading(name: "Water the plants", cadence: .timesPerWeek(9)),
    TaskReading(name: "Water the plants", cadence: .weekdays([])),
])
func anAnswerThatInventsANameOrAnImpossibleCadenceIsDropped(fromModel: TaskReading) async throws {
    let sentence = "Water the plants every couple of days or so"

    #expect(try await draft(sentence, model: fromModel) == TaskDraft(name: sentence, cadence: nil))
}

@Test func withoutAModelTheRulesAnswerAlone() async throws {
    #expect(try await draft("Renew my passport", model: nil) == TaskDraft(name: "Renew my passport", cadence: nil))
}

// MARK: Routine

@Test func aRoutineFromTheModelIsCheckedBeforeItIsUsed() async {
    var office = Routine.standard
    office.homeDays = [.monday, .friday]
    office.officeDays = [.tuesday, .wednesday, .thursday]
    var backwards = Routine.standard
    backwards.workEnd = DateComponents(hour: 8, minute: 0)
    var overlapping = Routine.standard
    overlapping.officeDays = [.monday]
    var impossible = Routine.standard
    impossible.bedtime = DateComponents(hour: 27, minute: 0)

    func read(_ routine: Routine?) async -> Routine? {
        await RoutineParser.routine(from: "I am at the office from Tuesday to Thursday", instructions: "", service: FixedService(routine: routine))
    }

    #expect(await read(office) == office)
    #expect(await read(backwards) == nil)
    #expect(await read(overlapping) == nil)
    #expect(await read(impossible) == nil)
    #expect(await read(nil) == nil)
    #expect(await RoutineParser.routine(from: "Anything", instructions: "", service: nil) == nil)
}
