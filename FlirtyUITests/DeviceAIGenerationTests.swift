import XCTest

/// Device-only tests for the real generation path.
///
/// These will FAIL on the simulator by design: there is no Apple Intelligence there,
/// and `--ui-testing` forces availability to `.available`, so generation reaches a
/// model that does not exist. Run them against a physical device with Apple
/// Intelligence enabled and the model downloaded:
///
///   xcodebuild test -project Flirty.xcodeproj -scheme Flirty \
///     -destination 'id=<device-udid>' \
///     -only-testing:FlirtyUITests/DeviceAIGenerationTests
///
/// They are excluded from the simulator suite runs documented in CLAUDE.md.
final class DeviceAIGenerationTests: XCTestCase {
    private var app: XCUIApplication!

    /// On-device generation is not fast. The model streams token by token and a cold
    /// first call also pays session setup.
    private let generationTimeout: TimeInterval = 120

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    // MARK: - Tests

    func testGeneratesStreamsAndCompletesAResponse() throws {
        openChat(withProfile: "Streaming")

        send("hey, what are you up to tonight?")

        // Copy/Regenerate only render once `isStreaming` is false, so their appearance
        // is the signal that streaming ran to completion.
        let copyButton = app.buttons["Copy"]
        XCTAssertTrue(
            copyButton.waitForExistence(timeout: generationTimeout),
            "Generation never completed — no Copy button after \(Int(generationTimeout))s"
        )

        let response = app.staticTexts["responseText"]
        XCTAssertTrue(response.exists, "Response bubble missing after generation")

        let text = response.label
        XCTAssertFalse(text.isEmpty, "Response was empty")
        XCTAssertNotEqual(text, "Thinking...", "Response never advanced past the placeholder")
        print("[DeviceTest] generated response: \(text)")
    }

    func testCopyConfirmsToTheUser() throws {
        openChat(withProfile: "Copying")
        send("what did you think of the film?")

        let copyButton = app.buttons["Copy"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: generationTimeout))
        copyButton.tap()

        // The label flips to "Copied" for 2s, the only user-visible confirmation that the
        // pasteboard write happened. Do NOT use waitForExistence here: it waits for app
        // quiescence first, and the pending 2s asyncAfter that reverts the label makes that
        // wait outlast the confirmation itself, so it reliably reports a false negative.
        // A direct snapshot query right after the tap sees it.
        XCTAssertTrue(app.buttons["Copied"].exists, "Copy gave no confirmation")
    }

    func testRegenerateProducesAFreshResponse() throws {
        openChat(withProfile: "Regenerating")
        send("tell me something about your week")

        let copyButton = app.buttons["Copy"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: generationTimeout))

        let first = app.staticTexts["responseText"].label
        let exchangesBefore = herLabelCount()

        app.buttons["Regenerate"].tap()

        // Do NOT assert on the transient streaming state (Copy vanishing): a warm session
        // can finish a regeneration between polls, so that check fails intermittently even
        // when regeneration worked. Assert the outcome — the response text is replaced.
        var second = first
        let deadline = Date().addingTimeInterval(generationTimeout)
        while Date() < deadline {
            let current = app.staticTexts["responseText"].label
            if !current.isEmpty, current != "Thinking...", current != first {
                second = current
                break
            }
            usleep(500_000)
        }

        XCTAssertNotEqual(second, first, "Regenerate did not produce a new response")

        // `second` is only a partial stream snapshot — the loop breaks on the first token
        // that differs. Wait for the action row to come back (safe in the existence
        // direction) so the assertions below see the *finished* response.
        XCTAssertTrue(
            copyButton.waitForExistence(timeout: generationTimeout),
            "Regenerated response never completed"
        )
        let final = app.staticTexts["responseText"].label
        XCTAssertFalse(final.isEmpty, "Regenerated response was empty")
        XCTAssertNotEqual(final, "Thinking...", "Regenerated response stuck on placeholder")
        print("[DeviceTest] first: \(first)")
        print("[DeviceTest] regenerated: \(final)")

        // Regeneration must overwrite the stored reply in place, not append a second
        // exchange for the same message — that was the other half of the original bug.
        // Leave and re-enter so these read persisted SwiftData, not the live bubble.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Regenerating"].waitForExistence(timeout: 10))
        app.staticTexts["Regenerating"].tap()
        XCTAssertTrue(app.textFields["herMessageField"].waitForExistence(timeout: 10))

        // Together these two prove overwrite-in-place: exactly one exchange still exists,
        // and it now holds the regenerated text, so the old reply cannot have survived.
        XCTAssertEqual(
            herLabelCount(), exchangesBefore,
            "Regenerate appended a duplicate exchange instead of replacing the reply"
        )
        XCTAssertTrue(
            historyText(startingWith: final).waitForExistence(timeout: 15),
            "Regenerated response was not written back to the stored exchange"
        )
    }

    /// Task 13 step 1: history must survive leaving and re-entering the chat.
    func testResponseHistoryPersistsAcrossNavigation() throws {
        let herMessage = "are we still on for saturday?"
        openChat(withProfile: "Persisting")
        send(herMessage)

        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: generationTimeout))
        let generated = app.staticTexts["responseText"].label

        // Back out to the list and return.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Persisting"].waitForExistence(timeout: 10))
        app.staticTexts["Persisting"].tap()

        // On re-entry `currentResponse` is empty, so `ResponseBubble` (and its
        // "responseText" identifier) is not rendered at all — history comes back through
        // `conversationHistory` as plain text. Assert on that, not on the bubble.
        XCTAssertTrue(
            app.staticTexts[herMessage].waitForExistence(timeout: 15),
            "Her message did not persist across navigation"
        )
        XCTAssertTrue(
            historyText(startingWith: generated).waitForExistence(timeout: 15),
            "Generated response did not persist across navigation"
        )
    }

    // MARK: - Helpers

    private func openChat(withProfile name: String) {
        app.buttons["addProfileButton"].tap()

        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        type(name, into: nameField)
        app.buttons["saveButton"].tap()

        let row = app.staticTexts[name]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        XCTAssertTrue(app.textFields["herMessageField"].waitForExistence(timeout: 10))
    }

    private func send(_ message: String) {
        type(message, into: app.textFields["herMessageField"])

        let generate = app.buttons["generateButton"]
        XCTAssertTrue(generate.isEnabled, "Generate button stayed disabled with text entered")
        generate.tap()
    }

    /// Looks up a rendered response by its opening characters.
    ///
    /// `app.staticTexts[someLongString]` cannot be used for model output: XCUITest throws
    /// "Invalid query - string identifier is too long" past ~128 characters, and responses
    /// regularly run longer. A prefix predicate is not subject to that limit.
    private func historyText(startingWith text: String) -> XCUIElement {
        let probe = String(text.prefix(60))
        return app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", probe))
            .firstMatch
    }

    /// Each stored exchange renders exactly one "Her:" caption in `conversationHistory`,
    /// so counting them counts persisted exchanges.
    private func herLabelCount() -> Int {
        app.staticTexts.matching(NSPredicate(format: "label == %@", "Her:")).count
    }

    /// A real device brings the keyboard up asynchronously, so `typeText` straight after
    /// `tap` intermittently throws "Neither element nor any descendant has keyboard focus".
    /// Wait for the keyboard before typing.
    private func type(_ text: String, into field: XCUIElement) {
        field.tap()
        XCTAssertTrue(
            app.keyboards.element.waitForExistence(timeout: 10),
            "Keyboard never appeared for \(field.identifier)"
        )
        field.typeText(text)
    }
}
