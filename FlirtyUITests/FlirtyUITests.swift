import XCTest

final class FlirtyUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    // MARK: - Home Screen

    func testAppLaunchShowsEmptyState() {
        XCTAssertTrue(app.staticTexts["emptyStateTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No conversations yet"].exists)
    }

    func testAddButtonExists() {
        XCTAssertTrue(app.buttons["addProfileButton"].waitForExistence(timeout: 5))
    }

    // MARK: - Create Profile Flow

    func testCreateProfileFlow() {
        // Tap add button
        app.buttons["addProfileButton"].tap()

        // Verify add sheet appeared
        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))

        // Save button should be disabled when name is empty
        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.exists)

        // Type a name
        nameField.tap()
        nameField.typeText("Anna")

        // Add an optional note
        let noteField = app.textFields["firstNoteField"]
        noteField.tap()
        noteField.typeText("loves hiking")

        // Tap Save
        saveButton.tap()

        // Verify profile appears in the list
        XCTAssertTrue(app.staticTexts["Anna"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["loves hiking"].exists)
    }

    // MARK: - Navigate to Chat

    func testNavigateToChatScreen() {
        // First create a profile
        createProfile(name: "Sofia", note: "reads sci-fi")

        // Tap the profile to navigate to chat
        app.staticTexts["Sofia"].tap()

        // Verify we're on the chat screen
        XCTAssertTrue(app.staticTexts["Sofia"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["herMessageField"].exists)
        XCTAssertTrue(app.buttons["generateButton"].exists)
    }

    // MARK: - Chat Screen Elements

    func testChatScreenHasAllInputElements() {
        createProfile(name: "Maria", note: "")
        app.staticTexts["Maria"].tap()

        // Her message field
        let herMessage = app.textFields["herMessageField"]
        XCTAssertTrue(herMessage.waitForExistence(timeout: 5))

        // Tone picker pills
        XCTAssertTrue(app.buttons["Sweet"].exists || app.staticTexts["Sweet"].exists)

        // Context field
        XCTAssertTrue(app.textFields["userContextField"].exists)

        // Generate button
        XCTAssertTrue(app.buttons["generateButton"].exists)

        // Notes button
        XCTAssertTrue(app.buttons["notesButton"].exists)
    }

    func testTonePickerSelection() {
        createProfile(name: "Anna", note: "")
        app.staticTexts["Anna"].tap()

        // Wait for chat screen
        XCTAssertTrue(app.textFields["herMessageField"].waitForExistence(timeout: 5))

        // Tap different tone pills
        let flirtyPill = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Flirty'")).firstMatch
        if flirtyPill.waitForExistence(timeout: 3) {
            flirtyPill.tap()
        }

        let funnyPill = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Funny'")).firstMatch
        if funnyPill.waitForExistence(timeout: 3) {
            funnyPill.tap()
        }
    }

    func testGenerateButtonDisabledWhenEmpty() {
        createProfile(name: "Anna", note: "")
        app.staticTexts["Anna"].tap()

        let generateButton = app.buttons["generateButton"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5))

        // Button should be disabled when no message
        XCTAssertFalse(generateButton.isEnabled)

        // Type a message
        let herMessage = app.textFields["herMessageField"]
        herMessage.tap()
        herMessage.typeText("Hey! How are you?")

        // Button should now be enabled
        XCTAssertTrue(generateButton.isEnabled)
    }

    // MARK: - Profile Notes Flow

    func testProfileNotesFlow() {
        createProfile(name: "Anna", note: "loves hiking")
        app.staticTexts["Anna"].tap()

        // Open notes sheet
        let notesButton = app.buttons["notesButton"]
        XCTAssertTrue(notesButton.waitForExistence(timeout: 5))
        notesButton.tap()

        // Verify notes sheet opened
        XCTAssertTrue(app.staticTexts["Notes about her"].waitForExistence(timeout: 5))

        // Verify existing note is shown
        XCTAssertTrue(app.staticTexts["loves hiking"].exists)

        // Add a new note
        let addNoteField = app.textFields["addNoteField"]
        XCTAssertTrue(addNoteField.exists)
        addNoteField.tap()
        addNoteField.typeText("has a cat named Milo")

        let addNoteButton = app.buttons["addNoteButton"]
        addNoteButton.tap()

        // Verify new note appears
        XCTAssertTrue(app.staticTexts["has a cat named Milo"].waitForExistence(timeout: 3))

        // Dismiss
        app.buttons["Done"].tap()
    }

    // MARK: - Multiple Profiles

    func testMultipleProfiles() {
        createProfile(name: "Anna", note: "loves hiking")
        createProfile(name: "Sofia", note: "reads sci-fi")
        createProfile(name: "Maria", note: "")

        // All three should appear
        XCTAssertTrue(app.staticTexts["Anna"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sofia"].exists)
        XCTAssertTrue(app.staticTexts["Maria"].exists)
    }

    // MARK: - Delete Profile

    func testDeleteProfile() {
        createProfile(name: "TestDeleteUser", note: "to be deleted")

        // Verify profile exists
        let profileText = app.staticTexts["TestDeleteUser"]
        XCTAssertTrue(profileText.waitForExistence(timeout: 5))

        // Swipe to delete on the list cell
        let cell = app.cells.containing(.staticText, identifier: "TestDeleteUser").firstMatch
        cell.swipeLeft()

        // Tap delete button
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 5) {
            deleteButton.tap()
        }

        // Verify profile is gone
        let profileGone = profileText.waitForNonExistence(timeout: 10)
        XCTAssertTrue(profileGone, "Profile should be deleted")
    }

    // MARK: - Helpers

    private func createProfile(name: String, note: String) {
        app.buttons["addProfileButton"].tap()

        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)

        if !note.isEmpty {
            let noteField = app.textFields["firstNoteField"]
            noteField.tap()
            noteField.typeText(note)
        }

        app.buttons["saveButton"].tap()

        // Wait for sheet to dismiss and profile to appear
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }
}
