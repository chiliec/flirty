import XCTest

/// Real generation through the cloud gateway. Runs on the simulator, which has no Apple
/// Intelligence, so `--simulate-ineligible` plus a local `Config/Secrets.xcconfig` is
/// exactly the ineligible-iPhone path. Costs real gateway calls and needs a network, so
/// it skips itself unless opted in:
///
///   TEST_RUNNER_FLIRTY_GATEWAY_SMOKE=1 xcodebuild test ... \
///     -only-testing:FlirtyUITests/GatewaySmokeTests
final class GatewaySmokeTests: XCTestCase {
    private var app: XCUIApplication!
    private let generationTimeout: TimeInterval = 90

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FLIRTY_GATEWAY_SMOKE"] == "1",
            "Set TEST_RUNNER_FLIRTY_GATEWAY_SMOKE=1 to hit the real gateway")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--simulate-ineligible"]
        app.launch()
    }

    func testGeneratesAndRegeneratesThroughTheGateway() {
        let allow = app.buttons["cloudConsentAllow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        allow.tap()

        app.buttons["addProfileButton"].tap()
        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Cloud")
        app.buttons["saveButton"].tap()
        let row = app.staticTexts["Cloud"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let field = app.textFields["herMessageField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("hey, what are you up to tonight?")
        app.buttons["generateButton"].tap()

        XCTAssertTrue(
            app.buttons["Copy"].waitForExistence(timeout: generationTimeout),
            "Gateway generation never completed")
        let first = app.staticTexts["responseText"].label
        XCTAssertFalse(first.isEmpty)
        XCTAssertNotEqual(first, "Thinking...")
        XCTAssertFalse(app.alerts["Error"].exists, "Generation raised an error alert")
        print("[GatewaySmoke] response: \(first)")

        // One stored exchange proves the reply was saved, not just streamed.
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Her:")).count, 1)

        app.buttons["Regenerate"].tap()
        let deadline = Date().addingTimeInterval(generationTimeout)
        var regenerated = first
        while Date() < deadline {
            regenerated = app.staticTexts["responseText"].label
            if !regenerated.isEmpty, regenerated != "Thinking...", regenerated != first { break }
            usleep(500_000)
        }
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: generationTimeout))
        XCTAssertNotEqual(app.staticTexts["responseText"].label, first, "Regenerate produced the same text")
        print("[GatewaySmoke] regenerated: \(app.staticTexts["responseText"].label)")
    }
}
