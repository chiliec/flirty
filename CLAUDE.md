# Flirty
iOS 26+ SwiftUI app. Generates romantic chat responses via Apple on-device Foundation Models (~3B parameter, 4096 token combined limit). No cloud, no API keys.

## Commands
```bash
xcodegen generate
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' build
xcodebuild test -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' -only-testing:FlirtyTests
xcodebuild test -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' -only-testing:FlirtyUITests
xcodebuild test ... -only-testing:FlirtyTests/ContextManagerTests/testName
```

## Architecture
`WomanProfile` + `Tone` → `ContextManager` (pure Swift struct, no framework deps, owns all prompt assembly + token budget) → `AIService` (streams response) → `Conversation` saved.

`ContextManager` uses `WomanProfileData` (lightweight snapshot) to avoid importing SwiftData.

## Critical Gotchas
- **`AIService` is `@MainActor @Observable`** — required by Swift 6.2 strict concurrency (SwiftUI views capture it across actor boundaries)
- **`Tone` stored as `toneRawValue: String`** in SwiftData `Conversation` — SwiftData doesn't support custom enum storage. Computed `tone` property converts.
- **4096 token limit**: last 2-3 exchanges verbatim + summarize older via separate `LanguageModelSession` call + store summary on `WomanProfile.conversationSummary`
- **`--ui-testing` launch arg**: bypasses `SystemLanguageModel.default.availability` check, uses in-memory SwiftData for test isolation
- **No AI verification on simulator**: there is no Apple Intelligence in the simulator, and `--ui-testing` forces `.available`. Any change touching generation, summarization, or the availability gate is unverified until run on a device — see Task 13 in `docs/superpowers/plans/2026-04-13-flirty-app.md`

## Foundation Models API
```swift
// Session init: trailing closure with @InstructionsBuilder
LanguageModelSession { "instructions string" }

// Streaming: returns snapshots — access fields as optional
session.streamResponse(to:generating:)  // partial.content.fieldName is Optional

session.prewarm()  // synchronous, NOT async — call on view appear
```
Apple content guardrails are mandatory and cannot be disabled.
