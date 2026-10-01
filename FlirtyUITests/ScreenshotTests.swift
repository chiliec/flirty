import XCTest

/// Captures App Store screenshots into `$SCREENSHOT_DIR`. Skipped unless that variable
/// is set on the runner (`TEST_RUNNER_SCREENSHOT_DIR=... xcodebuild test`), so CI and the
/// regular simulator suite never run it. Use the `(screenshots)` simulator with the status
/// bar overridden via `simctl status_bar`. The reply comes from `FLIRTY_STUB_RESPONSE`.
final class ScreenshotTests: XCTestCase {
    private static let herMessage = "so what are you doing this weekend?"
    private static let context = "free Saturday, know a jazz bar by the river"
    private static let reply =
        "Weekend's wide open, and that question just made it a lot more interesting. There's a tiny jazz bar by the river I've been saving for the right company. Saturday, 8?"

    private var directory: URL!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("SCREENSHOT_DIR not set")
        }
        directory = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment = ["FLIRTY_STUB_RESPONSE": Self.reply]
        app.launch()
    }

    private func snap(_ name: String) throws {
        // Let animations settle before capturing.
        Thread.sleep(forTimeInterval: 1)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try png.write(to: directory.appendingPathComponent("\(name).png"))
    }

    private func createProfile(_ name: String, note: String) {
        app.buttons["addProfileButton"].tap()
        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        let noteField = app.textFields["firstNoteField"]
        noteField.tap()
        noteField.typeText(note)
        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    func testCaptureAll() throws {
        createProfile("Anna", note: "loves hiking, just back from Lisbon")
        createProfile("Sofia", note: "reads sci-fi, works late shifts")
        createProfile("Maria", note: "runner, obsessed with coffee")
        try snap("01-list")

        app.staticTexts["Sofia"].tap()
        let field = app.textFields["herMessageField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(Self.herMessage)
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Flirty'")).firstMatch.tap()
        let context = app.textFields["userContextField"]
        context.tap()
        context.typeText(Self.context)
        app.swipeDown()  // the chat scroll view dismisses the keyboard on scroll
        try snap("02-chat-input")

        app.buttons["generateButton"].tap()
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 10))
        app.swipeDown()
        try snap("03-chat-reply")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let privacy = app.buttons["privacyButton"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        privacy.tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 5))
        try snap("04-privacy")
    }
}
