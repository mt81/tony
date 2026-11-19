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
    var draft: TaskDraft?
    var routine: Routine?

    func briefing(instructions: String, plan: String) async throws -> String { throw CocoaError(.featureUnsupported) }

    func taskDraft(instructions: String, sentence: String) async throws -> TaskDraft {
        guard let draft else { throw CocoaError(.featureUnsupported) }
        return draft
    }

    func routine(instructions: String, description: String) async throws -> Routine {
        guard let routine else { throw CocoaError(.featureUnsupported) }
        return routine
    }
}

private func draft(_ sentence: String, model: TaskDraft?) async -> TaskDraft {
    await TaskSentenceParser.draft(from: sentence, locale: Locale(identifier: "en"), instructions: "", service: FixedService(draft: model))
}

@Test func whatTheRulesUnderstandNeedsNoModel() async {
    let wrong = TaskDraft(name: "Water", cadence: .timesPerWeek(5))

    #expect(await draft("Water the plants every 5 days", model: wrong) == TaskDraft(name: "Water the plants", cadence: .every(5, .day)))
}

@Test func theModelReadsWhatTheRulesDoNot() async {
    let fromModel = TaskDraft(name: "water the plants", cadence: .every(3, .day))

    #expect(await draft("Water the plants every couple of days or so", model: fromModel) == fromModel)
}

@Test(arguments: [
    TaskDraft(name: "Feed the cat", cadence: .every(3, .day)),
    TaskDraft(name: "", cadence: .every(3, .day)),
    TaskDraft(name: "Water the plants", cadence: .every(0, .day)),
    TaskDraft(name: "Water the plants", cadence: .timesPerWeek(9)),
    TaskDraft(name: "Water the plants", cadence: .weekdays([])),
])
func anAnswerThatInventsANameOrAnImpossibleCadenceIsDropped(fromModel: TaskDraft) async {
    let sentence = "Water the plants every couple of days or so"

    #expect(await draft(sentence, model: fromModel) == TaskDraft(name: sentence, cadence: nil))
}

@Test func withoutAModelTheRulesAnswerAlone() async {
    #expect(await draft("Renew my passport", model: nil) == TaskDraft(name: "Renew my passport", cadence: nil))
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
