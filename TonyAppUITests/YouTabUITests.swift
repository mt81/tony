import XCTest

final class YouTabUITests: XCTestCase {
    /// The name entered in the You tab reaches the Today headline, and a task can be added from Today.
    @MainActor
    func testTheNameReachesTodayAndATaskCanBeAddedThere() {
        continueAfterFailure = false
        let tasks = TasksScreen()
        let app = tasks.app
        let taskName = "UITest From Today"

        tasks.openTasks()
        tasks.deleteLeftovers()

        app.buttons["You"].firstMatch.tap()
        setName("UITest Name", in: app)
        XCTAssertTrue(app.staticTexts["UITest Name"].waitForExistence(timeout: 5))

        app.buttons["Today"].firstMatch.tap()
        let headline = app.staticTexts["todayHeadline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5))
        XCTAssertTrue(headline.label.hasSuffix(", UITest Name"))

        let add = app.buttons["todayAddTask"]
        for _ in 0..<6 where !(add.exists && add.isHittable) {
            app.swipeUp()
        }
        add.tap()
        let field = app.textFields["taskName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(taskName)
        app.buttons["saveTask"].tap()

        tasks.openTasks()
        XCTAssertTrue(tasks.row(taskName).waitForExistence(timeout: 5))
        tasks.delete(taskName)

        app.buttons["You"].firstMatch.tap()
        setName("", in: app)
        XCTAssertTrue(app.staticTexts["You"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func setName(_ name: String, in app: XCUIApplication) {
        app.buttons["editRoutine"].tap()
        let field = app.textFields["userName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let current = field.value as? String ?? ""
        let erase = current == field.placeholderValue ? "" : String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
        field.typeText(erase + name)
        app.buttons["saveRoutine"].tap()
    }
}
