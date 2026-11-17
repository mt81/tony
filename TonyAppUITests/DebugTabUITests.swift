import XCTest

final class DebugTabUITests: XCTestCase {
    /// In debug builds, the Debug tab opens the model check, the calendar check and the component gallery.
    @MainActor
    func testTheDebugTabOpensEachDeveloperScreen() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let debugTab = app.buttons["Debug"].firstMatch
        XCTAssertTrue(debugTab.waitForExistence(timeout: 15))
        debugTab.tap()

        open("Model check", expecting: app.staticTexts["modelAvailability"], in: app)
        open("Calendar check", expecting: app.staticTexts["calendarAccess"], in: app)
        open("Component gallery", expecting: app.staticTexts["Components"], in: app)
    }

    @MainActor
    private func open(_ screen: String, expecting element: XCUIElement, in app: XCUIApplication) {
        app.buttons[screen].tap()
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(screen) did not open")
        app.navigationBars.buttons.firstMatch.tap()
    }
}
