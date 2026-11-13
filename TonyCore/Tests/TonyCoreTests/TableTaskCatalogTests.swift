import Foundation
import Testing
@testable import TonyCore

private let english = Locale(identifier: "en_US")
private let french = Locale(identifier: "fr_FR")

private let catalog = TableTaskCatalog(entries: [
    TableTaskCatalog.Entry(
        keywords: ["en": ["laundry"], "fr": ["lessive"]],
        steps: [
            TableTaskCatalog.StepEntry(name: ["en": "Load", "fr": "Remplir"], mode: .active, minutes: 10),
            TableTaskCatalog.StepEntry(name: ["en": "Wash", "fr": "Lavage"], mode: .background, minutes: 45, gapMinutes: 5),
        ]
    ),
    TableTaskCatalog.Entry(
        keywords: ["en": ["run"], "fr": ["courir", "course a pied"]],
        steps: [TableTaskCatalog.StepEntry(name: ["en": "Run", "fr": "Courir"], mode: .active, minutes: 45)]
    ),
    TableTaskCatalog.Entry(
        keywords: ["en": ["sheets"], "fr": ["draps"]],
        steps: [TableTaskCatalog.StepEntry(name: ["en": "Change the sheets"], mode: .active, minutes: 20)]
    ),
    TableTaskCatalog.Entry(
        keywords: ["en": ["bed sheets"], "fr": []],
        steps: [TableTaskCatalog.StepEntry(name: ["en": "Strip and remake the bed"], mode: .active, minutes: 25)]
    ),
])

private func stepNames(_ name: String, _ locale: Locale = english) -> [String]? {
    catalog.steps(forTaskNamed: name, locale: locale)?.map(\.name)
}

@Test func knownTaskGetsItsStepsWithModesAndDurations() {
    let steps = catalog.steps(forTaskNamed: "Do the laundry", locale: english)

    #expect(steps == [
        StepTemplate(name: "Load", mode: .active, duration: 10 * 60),
        StepTemplate(name: "Wash", mode: .background, duration: 45 * 60, minimumGapToNextStep: 5 * 60),
    ])
}

@Test(arguments: [
    (name: "Laundry", expected: ["Load", "Wash"] as [String]?),
    (name: "LAUNDRY!", expected: ["Load", "Wash"]),
    (name: "Go for a run", expected: ["Run"]),
    (name: "Running", expected: ["Run"]),
    (name: "Brunch with Sam", expected: nil),
    (name: "Renew the passport", expected: nil),
    (name: "", expected: nil),
])
func keywordsMatchAtTheStartOfAWord(name: String, expected: [String]?) {
    #expect(stepNames(name) == expected)
}

@Test func frenchNamesAndAccentsAreMatched() {
    #expect(stepNames("Faire la lessive", french) == ["Remplir", "Lavage"])
    #expect(stepNames("Course à pied", french) == ["Courir"])
}

@Test func theLongestMatchingKeywordWins() {
    #expect(stepNames("Change the bed sheets") == ["Strip and remake the bed"])
    #expect(stepNames("Wash the sheets") == ["Change the sheets"])
}

@Test func aStepWithoutAFrenchNameFallsBackToEnglish() {
    #expect(stepNames("Changer les draps", french) == ["Change the sheets"])
}

@Test func anotherLanguageUsesTheEnglishKeywords() {
    #expect(stepNames("Laundry", Locale(identifier: "de_DE")) == ["Load", "Wash"])
}

@Test func templateBecomesAStep() throws {
    let template = StepTemplate(name: "Wash", mode: .background, duration: 2700, minimumGapToNextStep: 300)
    let id = try Fixtures.identifier(7)

    #expect(template.step(id: id) == Step(id: id, name: "Wash", mode: .background, duration: 2700, minimumGapToNextStep: 300))
}

/// The table the app ships, read from the app's sources.
@Test func shippedTableIsCompleteInBothLanguages() throws {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../../TonyApp/Catalog/TaskCatalog.json")
    let shipped = try TableTaskCatalog(json: Data(contentsOf: url))

    #expect(!shipped.entries.isEmpty)
    for entry in shipped.entries {
        #expect(entry.keywords["en"]?.isEmpty == false)
        #expect(entry.keywords["fr"]?.isEmpty == false)
        #expect(!entry.steps.isEmpty)
        for step in entry.steps {
            #expect(step.name["en"]?.isEmpty == false)
            #expect(step.name["fr"]?.isEmpty == false)
            #expect(step.minutes > 0)
        }
    }
    #expect(shipped.steps(forTaskNamed: "Laundry", locale: english)?.map(\.duration) == [600, 2700, 300, 3600, 3600])
    #expect(shipped.steps(forTaskNamed: "Faire les courses", locale: french)?.map(\.name) == ["Faire les courses"])
    #expect(shipped.steps(forTaskNamed: "Course à pied", locale: french)?.map(\.name) == ["Courir"])
}
