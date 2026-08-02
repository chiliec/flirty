# Flirty
iOS 26+ SwiftUI app. Generates romantic chat responses via Apple on-device Foundation Models (~3B parameter, 4096 token combined limit). No cloud, no API keys.

## Commands
```bash
xcodegen generate   # rewrites the project; the Flirty scheme is declared in project.yml,
                    # do NOT hand-edit Flirty.xcscheme — regeneration deletes it

xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' build
xcodebuild test -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' -only-testing:FlirtyTests

# UI tests on simulator: DeviceAIGenerationTests must be skipped — it hits the real model.
xcodebuild test -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' -only-testing:FlirtyUITests -skip-testing:FlirtyUITests/DeviceAIGenerationTests

# The real generation path, physical device with Apple Intelligence enabled only.
# UNLOCK THE PHONE FIRST and set Auto-Lock to Never (Display & Brightness): a locked
# device installs the runner and then hangs forever instead of failing, because
# xcodebuild never surfaces SpringBoard's `FBSOpenApplicationErrorDomain error 7
# (Locked)`. A 120s generation timeout easily outlives a 30s auto-lock. To confirm a
# suspected lock rather than waiting it out:
#   xcrun devicectl device process launch --device <udid> com.flirty.app
xcodebuild test -project Flirty.xcodeproj -scheme Flirty -destination 'id=<device-udid>' -only-testing:FlirtyUITests/DeviceAIGenerationTests

xcodebuild test ... -only-testing:FlirtyTests/ContextManagerTests/testName
```
UI tests are timing-sensitive: a busy Mac (another agent driving a simulator) produces
off-screen taps, keyboard-focus failures and inflated runtimes that look like regressions.
Confirm on a quiet machine before believing a UI-test failure.

## Architecture
`WomanProfile` + `Tone` → `ContextManager` (pure Swift struct, no framework deps, owns all prompt assembly + token budget) → `AIService` (streams response) → `Conversation` saved.

`ContextManager` uses `WomanProfileData` (lightweight snapshot) to avoid importing SwiftData.

## Critical Gotchas
- **`AIService` is `@MainActor @Observable`** — required by Swift 6.2 strict concurrency (SwiftUI views capture it across actor boundaries)
- **`Tone` stored as `toneRawValue: String`** in SwiftData `Conversation` — SwiftData doesn't support custom enum storage. Computed `tone` property converts.
- **4096 token limit**: last 2-3 exchanges verbatim + summarize older via separate `LanguageModelSession` call + store summary on `WomanProfile.conversationSummary`
- **`--ui-testing` launch arg**: bypasses `SystemLanguageModel.default.availability` check, uses in-memory SwiftData for test isolation
- **`.modelNotReady` also means "Apple Intelligence is off"**: Apple documents `appleIntelligenceNotEnabled` and `modelNotReady` as distinct, but they are not. Verified on an iPhone 17e (eligible device, toggle off in Settings): `SystemLanguageModel.default.availability` returns `.unavailable(.modelNotReady)`. The `.notEnabled` branch may be unreachable on iOS 26 — keep it, but the `.notReady` gate copy is what users actually see and must tell them to enable Apple Intelligence, not just to wait for a download.
- **`--ui-testing` also renders a `summaryDiagnostic` label in `ChatView`**: `conversationSummary` and `summarizedExchangeCount` never reach the UI, so device tests read them from that label (`summarized:<n> summary:<text>`). It lives in the `ZStack`, not the scrolling stack — after five exchanges the top of the history has scrolled away.
- **No AI verification on simulator**: there is no Apple Intelligence in the simulator, and `--ui-testing` forces `.available`. Any change touching generation, summarization, or the availability gate is unverified until run on a device — see Task 13 in `docs/superpowers/plans/2026-04-13-flirty-app.md`. `FlirtyUITests/DeviceAIGenerationTests` covers the generation path and only passes on hardware.
- **Never look up model output with a string subscript**: `app.staticTexts[response]` throws `NSInternalInconsistencyException: Invalid query - string identifier is too long` past ~128 characters, and generated responses regularly exceed that. Such a test passes or fails on how verbose the model happened to be. Match a prefix with `NSPredicate(format: "label BEGINSWITH %@", ...)` instead — see `historyText(startingWith:)`.
- **Never wait on `app.keyboards` on a device**: if the phone's keyboard was last left in the Apple Intelligence Writing Tools panel, the input view publishes `keyboardPanel.*` elements and **no `Keyboard` element matches at all** — the field is focused and `typeText` works, but a keyboard-existence wait fails 100% of the time and looks like a keyboard-focus regression. Wait on the field taking focus instead; XCUIElement has no `hasKeyboardFocus` here, so read the trait off the snapshot (`debugDescription.contains("Keyboard Focused")`) — see `isKeyboardFocused(_:)`.
- **Only the chat screen scrolls**: a "scroll it into view" helper must wait for hittability *first* and only swipe when the chat is on screen. Swiping a presented sheet (the profile editor) drags it toward dismissal instead of scrolling, which breaks the very tap it was meant to enable.
- **Waiting on the Copy button only works for the first generation**: from the second one on, the previous response's button is already on screen, so the wait returns immediately and the test races the model. Wait on the exchange count in history instead — it is monotonic and only advances on success (`sendAndAwaitCompletion`).
- **Never assert on a transient UI state in a device test**: `waitForExistence` waits for app quiescence first, so a pending `asyncAfter` (e.g. the 2s "Copied" label revert) makes the wait outlast the state it is waiting for — a guaranteed false negative. Use a direct `.exists` snapshot for a state that is already on screen, and assert on outcomes (text changed) rather than on intermediate states like a streaming spinner, which a warm session can pass through between polls.

## Foundation Models API
```swift
// Session init: trailing closure with @InstructionsBuilder
LanguageModelSession { "instructions string" }

// Streaming: returns snapshots — access fields as optional
session.streamResponse(to:generating:)  // partial.content.fieldName is Optional

session.prewarm()  // synchronous, NOT async — call on view appear
```
Apple content guardrails are mandatory and cannot be disabled.
