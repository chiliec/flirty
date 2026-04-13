# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

This project uses **xcodegen** to manage the Xcode project. After adding or removing Swift files, regenerate the project:

```bash
xcodegen generate
```

Build:
```bash
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Run unit tests:
```bash
xcodebuild test -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FlirtyTests
```

Run UI tests:
```bash
xcodebuild test -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FlirtyUITests
```

Run a single test:
```bash
xcodebuild test -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FlirtyTests/ContextManagerTests/testName
```

## Architecture

**Flirty** is an iOS 26+ SwiftUI app that generates romantic chat responses using Apple's on-device Foundation Models (~3B parameter model, 4096 token combined limit). All AI runs locally — no cloud, no API keys.

### Data Flow

User creates a **WomanProfile** (name, notes) → pastes her message → selects a **Tone** → optionally adds real-life context → **ContextManager** assembles a token-budget-aware prompt → **AIService** streams a response via `LanguageModelSession` → response saved as a **Conversation**.

### Key Design Decisions

- **ContextManager** is a pure Swift struct (no framework dependencies) that owns all prompt assembly and token budget logic. It's the most testable part of the codebase. It uses `WomanProfileData` (a lightweight snapshot) to avoid importing SwiftData.
- **AIService** is `@MainActor @Observable` — required by Swift 6.2 strict concurrency because SwiftUI views capture it across actor boundaries. It wraps `LanguageModelSession` and handles streaming via `@Generable` structs.
- **Tone** is stored as `toneRawValue: String` in SwiftData's `Conversation` model (not the enum directly) because SwiftData doesn't support custom enum storage. A computed `tone` property converts between the two.
- **4096 token limit** is managed by keeping last 2-3 exchanges verbatim, summarizing older ones via a separate `LanguageModelSession` call, and storing the summary on `WomanProfile.conversationSummary`.
- **FlirtyApp** checks `SystemLanguageModel.default.availability` on launch and gates the UI behind it. The `--ui-testing` launch argument bypasses this check and uses in-memory SwiftData for test isolation.

### Foundation Models API Notes

- Session init: `LanguageModelSession { "instructions string" }` (trailing closure with `@InstructionsBuilder`)
- Streaming returns snapshots via `session.streamResponse(to:generating:)` — access fields as `partial.content.fieldName` (optional)
- `session.prewarm()` is synchronous (not async) — call on view appear
- Apple's content guardrails are mandatory and cannot be disabled
