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

    /// Without calendar access, Today offers to plan around events. The permission sheet opens from it and Not now closes it.
    @MainActor
    func testPlanAroundMyEventsOpensThePermissionSheet() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .calendar)
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launch()

        let planAroundEvents = app.buttons["planAroundEvents"]
        let grant = app.buttons["grantPermission"]
        XCTAssertTrue(planAroundEvents.waitForExistence(timeout: 5))
        planAroundEvents.tap()
        XCTAssertTrue(grant.waitForExistence(timeout: 5))
        XCTAssertEqual(grant.label, "Grant access")
        app.buttons["permissionNotNow"].tap()
        XCTAssertTrue(grant.waitForNonExistence(timeout: 5))
        XCTAssertTrue(planAroundEvents.exists)
    }
}
