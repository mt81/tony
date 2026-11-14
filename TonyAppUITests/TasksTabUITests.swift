import XCTest

/// UI tests need XCTest: Swift Testing cannot drive an app.
final class TasksTabUITests: XCTestCase {
    @MainActor
    func testTaskCreatedEditedReorderedAndDeletedSurvivesRelaunch() {
        continueAfterFailure = false
        TasksScreen().runCreateEditReorderDeleteAcrossRelaunches()
    }

    @MainActor
    func testNewTaskGetsItsStepsFromTheCatalogue() {
        continueAfterFailure = false
        TasksScreen().runCatalogueSuggestion()
    }
}

@MainActor
private struct TasksScreen {
    private let app = XCUIApplication()

    init() {
        app.launchArguments += ["-AppleLanguages", "(en)"]
    }

    func runCreateEditReorderDeleteAcrossRelaunches() {
        openTasks()
        deleteLeftovers()

        create("UITest Alpha")
        create("UITest Beta")
        XCTAssertLessThan(row("UITest Alpha").frame.minY, row("UITest Beta").frame.minY)

        row("UITest Alpha").tap()
        let name = app.textFields["taskName"]
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Alpha".count) + "Gamma")
        app.buttons["saveTask"].tap()
        XCTAssertTrue(row("UITest Gamma").waitForExistence(timeout: 5))
        XCTAssertFalse(row("UITest Alpha").exists)

        drag("UITest Beta", above: "UITest Gamma")
        XCTAssertTrue(isAbove("UITest Beta", "UITest Gamma"))

        relaunch()
        XCTAssertTrue(row("UITest Gamma").waitForExistence(timeout: 5))
        XCTAssertFalse(row("UITest Alpha").exists)
        XCTAssertLessThan(row("UITest Beta").frame.minY, row("UITest Gamma").frame.minY)

        delete("UITest Beta")
        relaunch()
        XCTAssertTrue(row("UITest Gamma").waitForExistence(timeout: 5))
        XCTAssertFalse(row("UITest Beta").exists)

        delete("UITest Gamma")
    }

    func runCatalogueSuggestion() {
        openTasks()
        app.buttons["addTask"].tap()
        let field = app.textFields["taskName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("UITest laundry")

        XCTAssertTrue(scrollToStep(named: "Load the washing machine"))
        XCTAssertTrue(scrollToStep(named: "Fold"))
        XCTAssertTrue(app.staticTexts["Suggested by Tony. Change anything that does not fit."].waitForExistence(timeout: 5))

        app.buttons["Cancel"].tap()
        XCTAssertFalse(row("UITest laundry").exists)
    }

    /// Drags one row past the top edge of another, slowly, and holds it there before letting go.
    /// Dropping on the other row's centre sits on the reorder threshold and fails now and then.
    private func drag(_ name: String, above other: String) {
        let start = row(name).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = row(other).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -0.25))
        start.press(forDuration: 1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.5)
    }

    /// Waits for the list to settle with the first row above the second.
    private func isAbove(_ name: String, _ other: String) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if row(name).frame.minY < row(other).frame.minY {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    /// Scrolls the editor down until a step with this name is on screen.
    private func scrollToStep(named name: String) -> Bool {
        let step = app.textFields.matching(NSPredicate(format: "value == %@", name)).firstMatch
        for _ in 0..<6 {
            if step.waitForExistence(timeout: 1), step.isHittable {
                return true
            }
            app.swipeUp()
        }
        return step.exists
    }

    private func openTasks() {
        app.launch()
        app.buttons["Tasks"].firstMatch.tap()
        XCTAssertTrue(app.buttons["addTask"].waitForExistence(timeout: 5))
    }

    private func relaunch() {
        app.terminate()
        openTasks()
    }

    private func row(_ name: String) -> XCUIElement {
        app.buttons["task-\(name)"]
    }

    private func create(_ name: String) {
        app.buttons["addTask"].tap()
        let field = app.textFields["taskName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["saveTask"].tap()
        XCTAssertTrue(row(name).waitForExistence(timeout: 5))
    }

    private func delete(_ name: String) {
        row(name).tap()
        let deleteButton = app.buttons["deleteTask"]
        if !deleteButton.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        deleteButton.tap()
        XCTAssertTrue(row(name).waitForNonExistence(timeout: 5))
    }

    private func deleteLeftovers() {
        let leftovers = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'task-UITest'"))
        while leftovers.count > 0 {
            let name = String(leftovers.firstMatch.identifier.dropFirst("task-".count))
            delete(name)
        }
    }
}
