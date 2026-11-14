import XCTest

final class FastUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEndToEndFlowAndCaptureScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemory"]
        app.launch()

        // 1. Timer Tab (initial idle state)
        XCTAssertTrue(app.staticTexts["Not fasting"].waitForExistence(timeout: 10))
        attachScreenshot(named: "01-timer-idle")

        // Start a 24h fast
        let startButton = app.buttons["Start 24h fast"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        XCTAssertTrue(app.staticTexts["Fasting"].waitForExistence(timeout: 5))
        attachScreenshot(named: "02-timer-active")

        // 2. Macros Tab: log a meal
        app.tabBars.buttons["Macros"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))

        app.buttons["Add meal"].tap()

        let descField = app.textFields["meal-description"]
        XCTAssertTrue(descField.waitForExistence(timeout: 5))
        descField.tap()
        descField.typeText("3 eggs and avocado")

        let proteinField = app.textFields["meal-protein"]
        proteinField.tap()
        proteinField.typeText("28")

        let caloriesField = app.textFields["meal-calories"]
        caloriesField.tap()
        caloriesField.typeText("450")

        app.navigationBars.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["3 eggs and avocado"].waitForExistence(timeout: 5))
        attachScreenshot(named: "03-macros")

        // 3. History Tab
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Last 14 days"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["In progress"].waitForExistence(timeout: 5))
        attachScreenshot(named: "04-history")

        // 4. Settings Tab
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Daily targets"].waitForExistence(timeout: 5))
        attachScreenshot(named: "05-settings")

        // 5. Return to Timer and End fast
        app.tabBars.buttons["Timer"].tap()
        app.buttons["End fast"].tap()
        XCTAssertTrue(app.navigationBars["End fast"].waitForExistence(timeout: 5))
        app.navigationBars["End fast"].buttons["End fast"].tap()
        XCTAssertTrue(app.staticTexts["Not fasting"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
