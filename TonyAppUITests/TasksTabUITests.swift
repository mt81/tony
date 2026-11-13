import XCTest

/// UI tests need XCTest: Swift Testing cannot drive an app.
final class TasksTabUITests: XCTestCase {
    @MainActor
    func testTaskCreatedEditedReorderedAndDeletedSurvivesRelaunch() {
        continueAfterFailure = false
        TasksScreen().runCreateEditReorderDeleteAcrossRelaunches()
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

        row("UITest Beta").press(forDuration: 1, thenDragTo: row("UITest Gamma"))
        XCTAssertLessThan(row("UITest Beta").frame.minY, row("UITest Gamma").frame.minY)

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
