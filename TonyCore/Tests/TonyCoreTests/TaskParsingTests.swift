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
    SentenceCase("Water the plants every 5 days", "en", "Water the plants", .afterCompletion(days: 5)),
    SentenceCase("water the plants every five days", "en", "Water the plants", .afterCompletion(days: 5)),
    SentenceCase("Every other day, stretch", "en", "Stretch", .afterCompletion(days: 2)),
    SentenceCase("Laundry every week", "en", "Laundry", .afterCompletion(days: 7)),
    SentenceCase("Change the bed sheets every 2 weeks", "en", "Change the bed sheets", .afterCompletion(days: 14)),
    SentenceCase("Take supplements daily", "en", "Take supplements", .afterCompletion(days: 1)),
    SentenceCase("Take out the trash every Tuesday", "en", "Take out the trash", .weekdays([.tuesday])),
    SentenceCase("Meal prep on Sundays and Wednesdays", "en", "Meal prep", .weekdays([.sunday, .wednesday])),
    SentenceCase("Go to the gym 3 times a week", "en", "Go to the gym", .timesPerWeek(3)),
    SentenceCase("Run twice a week", "en", "Run", .timesPerWeek(2)),
    SentenceCase("Renew my passport", "en", "Renew my passport", nil),
    SentenceCase("Water the plants every 900 days", "en", "Water the plants every 900 days", nil),
    SentenceCase("Arroser les plantes tous les 5 jours", "fr", "Arroser les plantes", .afterCompletion(days: 5)),
    SentenceCase("arroser les plantes tous les cinq jours", "fr", "Arroser les plantes", .afterCompletion(days: 5)),
    SentenceCase("Lessive chaque semaine", "fr", "Lessive", .afterCompletion(days: 7)),
    SentenceCase("Changer les draps toutes les 2 semaines", "fr", "Changer les draps", .afterCompletion(days: 14)),
    SentenceCase("Prendre les compléments tous les jours", "fr", "Prendre les compléments", .afterCompletion(days: 1)),
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
    #expect(TaskDraft(name: "Plants", cadence: .afterCompletion(days: 5)).kind == .recurring)
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

    #expect(await draft("Water the plants every 5 days", model: wrong) == TaskDraft(name: "Water the plants", cadence: .afterCompletion(days: 5)))
}

@Test func theModelReadsWhatTheRulesDoNot() async {
    let fromModel = TaskDraft(name: "water the plants", cadence: .afterCompletion(days: 3))

    #expect(await draft("Water the plants every couple of days or so", model: fromModel) == fromModel)
}

@Test(arguments: [
    TaskDraft(name: "Feed the cat", cadence: .afterCompletion(days: 3)),
    TaskDraft(name: "", cadence: .afterCompletion(days: 3)),
    TaskDraft(name: "Water the plants", cadence: .afterCompletion(days: 0)),
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
