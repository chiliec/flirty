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
        let final = awaitResponseChange(from: first)
        XCTAssertFalse(final.isEmpty, "Regenerated response was empty")
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

    /// Task 13 step 1: aged-out exchanges must be folded into `conversationSummary` once,
    /// and only once.
    ///
    /// This is the only test that exercises the token budget: three exchanges stay verbatim,
    /// so summarization cannot happen at all until a fourth is stored. It reads the state
    /// through the `--ui-testing`-only `summaryDiagnostic` label, because neither
    /// `conversationSummary` nor `summarizedExchangeCount` is otherwise visible outside a
    /// debugger. Seven real generations — expect a few minutes.
    func testSummarizationFoldsAgedOutExchangesIntoTheStoredSummary() throws {
        openChat(withProfile: "Summarizing")

        // Exchange 1 carries the detail that must survive being summarized away.
        let openers = [
            "guess what — I finally adopted a kitten and named her Waffles!",
            "work was a mess today, three meetings back to back",
            "I'm thinking of driving out to the coast this weekend",
            "did you ever finish that book you were telling me about?",
        ]
        for (index, message) in openers.enumerated() {
            sendAndAwaitCompletion(message, expectedExchanges: index + 1)
        }

        // Four stored exchanges, three of them verbatim: the fourth generation still saw
        // only three, so nothing has aged out yet and no summary should exist.
        let beforeSummarization = summaryDiagnostic()
        XCTAssertEqual(
            summarizedCount(beforeSummarization), 0,
            "Summarization ran while every exchange still fit verbatim: \(beforeSummarization)"
        )
        XCTAssertTrue(
            summaryText(beforeSummarization).isEmpty,
            "A summary was stored before any exchange aged out: \(beforeSummarization)"
        )

        // The fifth generation is the first to see four stored exchanges, so exchange 1
        // ages out and gets folded into a summary.
        sendAndAwaitCompletion("what do you think of the name I picked for her?", expectedExchanges: 5)

        let afterFirstSummary = summaryDiagnostic()
        let firstSummary = summaryText(afterFirstSummary)
        XCTAssertEqual(
            summarizedCount(afterFirstSummary), 1,
            "First aged-out exchange was not counted: \(afterFirstSummary)"
        )
        XCTAssertFalse(firstSummary.isEmpty, "Aged-out exchange produced no summary")
        print("[DeviceTest] summary after 5 exchanges: \(firstSummary)")

        // The summary has to actually carry exchange 1 forward — it is the only kitten
        // content in the history at that point, so this is what "context survived being
        // summarized away" looks like.
        let lowercased = firstSummary.lowercased()
        XCTAssertTrue(
            ["waffles", "kitten", "cat"].contains(where: lowercased.contains),
            "Summary lost the content of the exchange it summarized: \(firstSummary)"
        )

        // A sixth exchange ages out exchange 2, which must be folded into the existing
        // summary rather than the summary being left stale.
        sendAndAwaitCompletion("remind me — what name did I settle on for her?", expectedExchanges: 6)

        let afterSecondSummary = summaryDiagnostic()
        XCTAssertEqual(
            summarizedCount(afterSecondSummary), 2,
            "Second aged-out exchange was not folded in: \(afterSecondSummary)"
        )
        XCTAssertNotEqual(
            summaryText(afterSecondSummary), firstSummary,
            "Summary was not refreshed when a new exchange aged out"
        )
        print("[DeviceTest] summary after 6 exchanges: \(summaryText(afterSecondSummary))")

        // Whether the reply itself uses the summarized-away detail is a judgement call, so
        // it is printed rather than asserted; that the stored summary reaches the prompt is
        // covered by ContextManagerTests.
        let beforeRegenerate = app.staticTexts["responseText"].label
        print("[DeviceTest] reply with summary in context: \(beforeRegenerate)")

        // Regeneration replays the last exchange with that exchange dropped from the
        // history, so nothing new ages out — summarization must not run again. Re-running it
        // would burn a model call per tap and rewrite a summary that is already correct.
        app.buttons["Regenerate"].tap()
        let regenerated = awaitResponseChange(from: beforeRegenerate)
        XCTAssertFalse(regenerated.isEmpty, "Regeneration never completed")

        XCTAssertEqual(
            summaryDiagnostic(), afterSecondSummary,
            "Summarization re-ran even though no new exchange had aged out"
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
        scrollIntoView(generate)
        generate.tap()
    }

    /// Sends a message and waits for the exchange to be *stored*.
    ///
    /// Waiting on the Copy button only works for the first generation — after that the
    /// button from the previous response is already on screen, so the wait returns
    /// immediately. The exchange count is monotonic and only advances on success, which
    /// makes it the one reliable completion signal in a multi-turn conversation.
    private func sendAndAwaitCompletion(_ message: String, expectedExchanges: Int) {
        send(message)

        let deadline = Date().addingTimeInterval(generationTimeout)
        while Date() < deadline {
            if herLabelCount() >= expectedExchanges { return }
            usleep(500_000)
        }
        XCTFail(
            "Generation \(expectedExchanges) never completed — history still shows "
            + "\(herLabelCount()) exchange(s) after \(Int(generationTimeout))s"
        )
    }

    /// Waits out a regeneration and returns the finished response.
    ///
    /// Do NOT assert on the transient streaming state (Copy vanishing): a warm session can
    /// finish between polls, so that check fails intermittently even when regeneration
    /// worked. Poll for the text changing, then wait for the action row to come back — that
    /// wait is safe in the existence direction and guarantees the response is complete
    /// rather than a mid-stream snapshot.
    @discardableResult
    private func awaitResponseChange(from previous: String) -> String {
        let response = app.staticTexts["responseText"]

        let deadline = Date().addingTimeInterval(generationTimeout)
        while Date() < deadline {
            let current = response.label
            if !current.isEmpty, current != "Thinking...", current != previous { break }
            usleep(500_000)
        }

        XCTAssertTrue(
            app.buttons["Copy"].waitForExistence(timeout: generationTimeout),
            "Regenerated response never completed"
        )
        let final = response.label
        XCTAssertNotEqual(final, previous, "Regenerate did not produce a new response")
        XCTAssertNotEqual(final, "Thinking...", "Regenerated response stuck on placeholder")
        return final
    }

    /// The `--ui-testing`-only label carrying `summarizedExchangeCount` and
    /// `conversationSummary`, formatted as `summarized:<n> summary:<text>`.
    private func summaryDiagnostic() -> String {
        let element = app.staticTexts["summaryDiagnostic"]
        XCTAssertTrue(
            element.exists,
            "Summary diagnostic is missing — is the app running with --ui-testing?"
        )
        return element.label
    }

    private func summarizedCount(_ diagnostic: String) -> Int {
        guard let token = diagnostic.split(separator: " ").first,
              let count = Int(token.replacingOccurrences(of: "summarized:", with: "")) else {
            XCTFail("Unparseable summary diagnostic: \(diagnostic)")
            return -1
        }
        return count
    }

    private func summaryText(_ diagnostic: String) -> String {
        guard let range = diagnostic.range(of: "summary:") else {
            XCTFail("Unparseable summary diagnostic: \(diagnostic)")
            return ""
        }
        return String(diagnostic[range.upperBound...])
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
    ///
    /// Wait on the field taking focus, not on `app.keyboards` existing: if the phone's
    /// keyboard was last left in the Apple Intelligence Writing Tools panel, the input view
    /// is published as `keyboardPanel.*` elements and no `Keyboard` element matches at all —
    /// the field is focused and typing works fine, but a keyboard-existence wait fails every
    /// time. Focus is the actual precondition for `typeText`.
    private func type(_ text: String, into field: XCUIElement) {
        scrollIntoView(field)
        field.tap()

        let deadline = Date().addingTimeInterval(10)
        var focused = false
        while Date() < deadline {
            if app.keyboards.element.exists || isKeyboardFocused(field) {
                focused = true
                break
            }
            usleep(500_000)
        }
        XCTAssertTrue(focused, "\(field.identifier) never took keyboard focus")

        field.typeText(text)
    }

    /// XCUIElement exposes no `hasKeyboardFocus` in this XCTest, but the element snapshot
    /// carries the trait, and the snapshot's description is where it surfaces.
    private func isKeyboardFocused(_ field: XCUIElement) -> Bool {
        field.exists && field.debugDescription.contains("Keyboard Focused")
    }

    /// A long conversation pushes the input area past the bottom of the scroll view, and
    /// tapping an element that is not hittable throws. The chat scrolls itself to the
    /// bottom after each response, so the input area is always *above* the visible region —
    /// swiping down brings it back. A no-op for a short conversation.
    ///
    /// The hittability wait comes first, and the swipe is gated on being in the chat: an
    /// element that is merely mid-presentation is not off-screen, and swiping a presented
    /// sheet drags it toward dismissal instead of scrolling anything.
    private func scrollIntoView(_ element: XCUIElement) {
        if waitForHittable(element, timeout: 5) { return }
        guard app.textFields["herMessageField"].exists else { return }

        var attempts = 0
        while !element.isHittable, attempts < 4 {
            app.scrollViews.firstMatch.swipeDown()
            attempts += 1
        }
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isHittable { return true }
            usleep(200_000)
        }
        return false
    }
}
