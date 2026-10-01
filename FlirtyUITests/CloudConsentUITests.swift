import XCTest

/// The cloud tier's consent gate, driven with `--simulate-ineligible` so it runs on the
/// simulator without a gateway key or network. Generation itself is never exercised.
final class CloudConsentUITests: XCTestCase {
    func testConsentUnlocksAppAndCanBeRevoked() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--simulate-ineligible"]
        app.launch()

        let allow = app.buttons["cloudConsentAllow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        allow.tap()

        XCTAssertTrue(app.staticTexts["emptyStateTitle"].waitForExistence(timeout: 5))

        app.buttons["cloudModeMenu"].tap()
        let toggle = app.descendants(matching: .any).matching(identifier: "cloudModeToggle").firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()

        XCTAssertTrue(allow.waitForExistence(timeout: 5))
    }

    func testEligibleDeviceShowsNoCloudMenu() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["emptyStateTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cloudModeMenu"].exists)
    }
}
