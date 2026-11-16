import Foundation
import Synchronization
import Testing
@testable import TonyCore

private func request(
    items: [BriefingRequest.Item] = [
        .init(time: "08:00", title: "Plants", reason: "The first moment that fits."),
        .init(time: "12:30", title: "Laundry · Wash", reason: "It runs on its own."),
        .init(time: "18:00", title: "Gym", reason: "Kept for the evening."),
    ],
    otherTaskNames: [String] = ["Vacuum", "Passport"]
) -> BriefingRequest {
    BriefingRequest(
        instructions: "Word this day.",
        header: ["Tuesday 10 November"],
        items: items,
        footer: ["Busy from 10:00 to 11:00"],
        allowedMinutes: [480, 750, 1080, 600, 660],
        otherTaskNames: otherTaskNames,
        fallback: "3 things would be nice today: Plants, Laundry and Gym."
    )
}

/// Answers with the given texts in turn; a nil is a model that cannot answer.
private final class ScriptedService: LanguageService {
    private let answers: Mutex<[String?]>
    private let calls = Mutex<[String]>([])

    init(_ answers: [String?]) {
        self.answers = Mutex(answers)
    }

    var plans: [String] { calls.withLock { $0 } }

    func briefing(instructions: String, plan: String) async throws -> String {
        calls.withLock { $0.append(plan) }
        guard let answer = answers.withLock({ $0.isEmpty ? nil : $0.removeFirst() }) else {
            throw CocoaError(.featureUnsupported)
        }
        return answer
    }

    func taskDraft(instructions: String, sentence: String) async throws -> TaskDraft { throw CocoaError(.featureUnsupported) }
    func routine(instructions: String, description: String) async throws -> Routine { throw CocoaError(.featureUnsupported) }
}

// MARK: Validation

struct BriefingCase: Sendable, CustomTestStringConvertible {
    var testDescription: String
    var text: String
    var problems: [BriefingValidator.Problem]
}

@Test(arguments: [
    BriefingCase(
        testDescription: "names plan tasks and plan times",
        text: "Start with the plants at 8:00. The laundry can run from 12:30, and the gym waits until 6 pm, after your 10:00 meetings.",
        problems: []
    ),
    BriefingCase(testDescription: "names no time at all", text: "A calm day: plants, laundry, then the gym tonight.", problems: []),
    BriefingCase(testDescription: "a time not in the plan", text: "Water the plants at 9:15.", problems: [.unknownTime(minutes: 555)]),
    BriefingCase(testDescription: "a French time not in the plan", text: "Les Plants à 8 h, le Gym à 19h30.", problems: [.unknownTime(minutes: 1170)]),
    BriefingCase(testDescription: "a task that is not planned today", text: "Plants first, then vacuum the flat.", problems: [.unplannedTask("Vacuum")]),
    BriefingCase(testDescription: "none of the planned tasks", text: "Have a lovely day.", problems: [.namesNoTask]),
    BriefingCase(testDescription: "nothing", text: "  \n", problems: [.empty]),
    BriefingCase(testDescription: "too long", text: "Plants. " + String(repeating: "Take it easy. ", count: 50), problems: [.tooLong]),
])
func aBriefingMayOnlyNameWhatIsInThePlan(_ briefingCase: BriefingCase) {
    #expect(BriefingValidator.problems(in: briefingCase.text, for: request()) == briefingCase.problems)
}

@Test func timesAreReadInBothLanguages() {
    #expect(BriefingValidator.minutesOfDay(in: "À 8 h les plantes, à 12h30 la lessive, à 18:00 le sport.") == [480, 750, 1080])
    #expect(BriefingValidator.minutesOfDay(in: "Plants at 8 am, gym at 6:30 PM, 3 meetings.") == [480, 1110])
}

@Test func anUnplannedTaskWhoseNameIsInThePlanIsNotAProblem() {
    let sameName = request(otherTaskNames: ["Laundry"])

    #expect(BriefingValidator.problems(in: "Plants, then the laundry.", for: sameName).isEmpty)
}

@Test func anEmptyDayNeedsNoTaskName() {
    #expect(BriefingValidator.problems(in: "Nothing needs you today.", for: request(items: [])).isEmpty)
}

// MARK: Prompt

@Test func thePromptListsTheDayTheTasksWithReasonsAndTheBusyTime() {
    #expect(request().prompt() == """
        Tuesday 10 November
        08:00 Plants. The first moment that fits.
        12:30 Laundry · Wash. It runs on its own.
        18:00 Gym. Kept for the evening.
        Busy from 10:00 to 11:00
        """)
}

@Test func overTheBudgetReasonsGoFirstThenTheLastTasks() {
    let withoutReasons = request().prompt(characterBudget: 90)
    let twoTasks = request().prompt(characterBudget: 80)

    #expect(withoutReasons == "Tuesday 10 November\n08:00 Plants\n12:30 Laundry · Wash\n18:00 Gym\nBusy from 10:00 to 11:00")
    #expect(twoTasks == "Tuesday 10 November\n08:00 Plants\n12:30 Laundry · Wash\nBusy from 10:00 to 11:00")
    #expect(request().prompt().count <= BriefingRequest.characterBudget)
}

// MARK: Writer

@Test func aValidAnswerIsUsedAndKeptForTheSamePlan() async {
    let service = ScriptedService(["  Plants at 8:00, then the gym.\n"])
    let writer = BriefingWriter(service: service)

    let first = await writer.briefing(for: request())
    let second = await writer.briefing(for: request())

    #expect(first == Briefing(text: "Plants at 8:00, then the gym.", source: .model))
    #expect(second == first)
    #expect(service.plans == [request().prompt()])
}

@Test func anInvalidAnswerIsRetriedOnce() async {
    let service = ScriptedService(["Plants at 9:15.", "Plants at 8:00."])
    let writer = BriefingWriter(service: service)

    #expect(await writer.briefing(for: request()) == Briefing(text: "Plants at 8:00.", source: .model))
    #expect(service.plans.count == 2)
}

@Test func twoInvalidAnswersGiveTheTemplateAndTheModelIsNotAskedAgain() async {
    let service = ScriptedService(["Plants at 9:15.", "Vacuum at 8:00.", "Plants at 8:00."])
    let writer = BriefingWriter(service: service)

    let first = await writer.briefing(for: request())
    let second = await writer.briefing(for: request())

    #expect(first == Briefing(text: request().fallback, source: .template))
    #expect(second == first)
    #expect(service.plans.count == 2)
}

@Test func aModelThatCannotAnswerGivesTheTemplateAndIsAskedAgainNextTime() async {
    let service = ScriptedService([nil, nil, "Plants at 8:00."])
    let writer = BriefingWriter(service: service)

    #expect(await writer.briefing(for: request()).source == .template)
    #expect(await writer.briefing(for: request()) == Briefing(text: "Plants at 8:00.", source: .model))
}

@Test func aChangedPlanIsWordedAgain() async {
    let service = ScriptedService(["Plants at 8:00.", "Only the plants today."])
    let writer = BriefingWriter(service: service)
    let smaller = request(items: [.init(time: "08:00", title: "Plants", reason: "The first moment that fits.")])

    _ = await writer.briefing(for: request())

    #expect(await writer.briefing(for: smaller).text == "Only the plants today.")
}

@Test func withoutAServiceTheBriefingIsTheTemplate() async {
    #expect(await BriefingWriter(service: nil).briefing(for: request()) == Briefing(text: request().fallback, source: .template))
}
