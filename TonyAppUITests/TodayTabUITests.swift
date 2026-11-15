import XCTest

final class TodayTabUITests: XCTestCase {
    /// A task with a deadline is always suggested, whatever else is in the store.
    @MainActor
    func testATaskShowsInTodayAndLeavesWhenChecked() {
        continueAfterFailure = false
        let tasks = TasksScreen(arguments: ["-now", "08:00"])
        let app = tasks.app
        let name = "UITest Today"

        tasks.openTasks()
        tasks.deleteLeftovers()
        tasks.create(name, hasDeadline: true)

        app.buttons["Today"].firstMatch.tap()
        let item = app.descendants(matching: .any)["today-item-\(name)"]
        let check = app.buttons["today-check-\(name)"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        for _ in 0..<6 where !check.isHittable {
            app.swipeUp()
        }
        check.tap()
        XCTAssertTrue(item.waitForNonExistence(timeout: 5))

        tasks.openTasks()
        tasks.delete(name)
    }
}
