# Flirty — iOS App Design Spec

**Date:** 2026-04-13
**Platform:** iOS 26+ (SwiftUI)
**AI Backend:** Apple Foundation Models (on-device)

## Overview

Flirty is a native iOS app that helps men craft thoughtful, romantic, and genuine chat responses when messaging women. The user creates a profile for each woman with her name and personal notes, then pastes her messages into the app and receives AI-generated response suggestions — personalized by tone selection, real-life context, and conversation history.

All AI processing runs on-device via Apple's Foundation Models framework. No API keys, no cloud, no data leaves the device.

## Target User

Men who want to be more romantic, caring, and expressive in text conversations but struggle to find the right words. The app is a communication assistant — not a catfishing tool. It uses the user's real context to craft authentic responses.

## Core User Flow

1. User opens the app and sees a list of women profiles
2. User taps a profile (or creates a new one)
3. User pastes her latest message
4. User selects a tone (Flirty / Sweet / Funny / Poetic / Caring)
5. User optionally adds real-life context ("my day was actually great, had a productive meeting")
6. User taps "Generate Response"
7. AI response streams in with typing animation
8. User copies the response to clipboard or regenerates

## Screens

### 1. Women List (Home)

- Displays all woman profiles as cards
- Each card shows: avatar initial (unique gradient), name, profile notes preview, chat count
- "+" button in top-right to add a new profile
- Tapping a card navigates to the Chat Screen
- Swipe to delete a profile

### 2. Chat Screen

The main interaction screen, structured top-to-bottom:

- **Navigation bar:** Back button, avatar + name, "Notes" button (opens profile notes sheet)
- **Conversation history:** Scrollable area showing previous exchanges (her message + generated response pairs), most recent at bottom
- **Input area:**
  - "Her message" text field (multi-line, paste-friendly)
  - Tone picker: horizontal scrollable pill selector with 5 options
  - "Your context" text field (optional, single-line, placeholder: "Add real context...")
  - "Generate Response" button (gradient, full-width)
- **Response area:** Appears inline below the generate button after generation
  - Shows the AI response with streaming typing animation
  - Two action buttons: "Copy" and "Regenerate"
  - The exchange (her message + generated response) is saved to conversation history immediately after generation completes

### 3. Profile Notes (Sheet)

- Presented as a sheet from Chat Screen
- Name field (editable)
- Notes list: each note is a short string ("loves hiking", "has a cat named Milo")
- Add note button, swipe to delete
- Notes are used in every AI prompt to personalize responses

### 4. Add Woman (Sheet)

- Name field (required)
- Optional first note
- Save button creates the profile and navigates to Chat Screen

## Data Model (SwiftData)

### WomanProfile

| Field | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| name | String | Her name |
| gradientIndex | Int | Index into predefined avatar gradient pairs |
| notes | [String] | Profile notes ("loves hiking", etc.) |
| conversationSummary | String? | Compressed summary of older exchanges |
| createdAt | Date | Creation timestamp |
| conversations | [Conversation] | Relationship to conversations |

### Conversation

| Field | Type | Description |
|---|---|---|
| id | UUID | Primary key |
| herMessage | String | What she said |
| userContext | String? | Optional real-life context from user |
| tone | Tone | Selected tone for this request |
| generatedResponse | String | AI-generated response |
| createdAt | Date | Creation timestamp |
| womanProfile | WomanProfile | Back-reference |

### Tone (Enum)

```swift
enum Tone: String, Codable, CaseIterable {
    case flirty
    case sweet
    case funny
    case poetic
    case caring
}
```

Each case has a display name, icon, and tone modifier string for the AI prompt.

## AI Integration

### Framework

Apple Foundation Models (iOS 26+). Uses `LanguageModelSession` for stateful conversations and `@Generable` for structured output.

### Availability Check

On app launch, check `SystemLanguageModel.default.availability`:

| State | User-facing behavior |
|---|---|
| `.available` | Normal flow |
| `.appleIntelligenceNotEnabled` | Show message: "Enable Apple Intelligence in Settings" |
| `.deviceNotEligible` | Show message: "Requires iPhone with Apple Intelligence support" |
| `.modelNotReady` | Show message: "AI model is downloading..." with retry |

### Structured Output

```swift
@Generable
struct FlirtyResponse {
    @Guide(description: "The chat message response, 2-4 sentences")
    var message: String
}
```

### System Instructions

```
You are a thoughtful assistant helping craft a message to {name}.
Your response should sound natural — like something a real person
would actually type in a chat. Match the tone: {tone}.

Rules:
- Write ONLY the message text, no labels or quotes
- Keep it concise (2-4 sentences typically)
- Be genuine, not cliche or over-the-top
- Use the context provided — never invent facts about the user's life
- Match the energy level of her message
- If she asked a question, answer it using the user's real context
```

### Tone Modifiers

| Tone | Modifier appended to system instructions |
|---|---|
| Flirty | "Be playfully confident. Light teasing is good. Add subtle tension." |
| Sweet | "Be warm and affectionate. Show you care about the details she shares." |
| Funny | "Be witty and lighthearted. Use humor naturally, not forced jokes." |
| Poetic | "Be expressive and eloquent. Use vivid language and metaphors sparingly." |
| Caring | "Be supportive and attentive. Show empathy and genuine interest in her feelings." |

### Prompt Assembly

The ContextManager assembles the full prompt within the 4,096 token budget:

```
[System Instructions + Tone Modifier]

About her: {profile notes, comma-separated}

Previous conversation:
{conversation summary, if exists}
{last 2-3 verbatim exchanges:}
  Her: {message}
  You replied: {response}

---
Her new message: {current message}
Real context from user: {user context, if provided}

Write a {tone} response:
```

### Token Budget

| Component | ~Tokens | Purpose |
|---|---|---|
| System instructions + tone | ~200 | Persona and tone guidance |
| Profile notes | ~100 | Her interests and facts |
| Conversation summary | ~200 | Compressed older history |
| Last 2-3 exchanges | ~400 | Recent conversation continuity |
| Her current message | ~100 | What she just said |
| User context | ~50 | Real-life details |
| **Output budget** | **~500-600** | Generated response |
| **Safety margin** | ~200 | Token estimation variance |

### Context Window Management

**Trigger:** Before each generation, ContextManager estimates total token count. If it exceeds ~3,200 tokens (leaving ~900 for output + safety), summarization is triggered.

**Summarization process:**
1. Take all exchanges except the last 2
2. Generate a summary using a separate `LanguageModelSession`: "Summarize this conversation history in 2-3 sentences. Focus on: topics discussed, plans made, emotional tone, and personal details shared."
3. Store the summary on `WomanProfile.conversationSummary`
4. Re-summarize after every 3 new exchanges (not every request)

**Overflow handling:** If total still exceeds budget after summarization:
1. Drop the summary
2. Reduce to last 1 exchange
3. If still over, truncate her message

### Session Lifecycle

- **New session** created when user navigates to a Chat Screen
- `session.prewarm()` called on navigation (preloads model before user needs it)
- **Session discarded** when app is backgrounded (iOS may reclaim memory)
- **Session rebuilt** from SwiftData on return (summary + recent exchanges)
- SwiftData is the source of truth; sessions are ephemeral

### Guardrail Risk

Apple's mandatory content guardrails cannot be disabled. The prompt is framed as "helping craft a message" (communication assistant), not roleplaying or generating explicit content. Tones stay within romantic/sweet territory.

**Fallback plan if guardrails block responses:**
1. Simplify system prompt — replace "flirty" with "charming"
2. Remove romance framing entirely — let tone modifiers do the work
3. If on-device is too restrictive, evaluate adding cloud API option in future version

## Architecture

```
FlirtyApp/
├── App/
│   └── FlirtyApp.swift              — Entry point, SwiftData container
├── Models/
│   ├── WomanProfile.swift           — SwiftData @Model
│   ├── Conversation.swift           — SwiftData @Model
│   └── Tone.swift                   — Enum with display properties
├── Services/
│   ├── AIService.swift              — Foundation Models session wrapper
│   └── ContextManager.swift         — Token budget & prompt assembly
├── Views/
│   ├── WomenListView.swift          — Home screen
│   ├── AddWomanView.swift           — New profile sheet
│   ├── ChatView.swift               — Main interaction screen
│   ├── ProfileNotesView.swift       — Edit profile notes sheet
│   ├── ResponseView.swift           — AI response display (inline)
│   └── TonePicker.swift             — Horizontal pill selector
└── Resources/
    └── Assets.xcassets               — App icon, colors
```

### Key Responsibilities

- **AIService:** Wraps `LanguageModelSession`. Exposes `generate(prompt:) -> AsyncStream<String>` for streaming and `summarize(exchanges:) -> String` for history compression. Handles availability checks and errors.
- **ContextManager:** Owns token budget logic. Takes a `WomanProfile`, her current message, user context, and tone — returns an assembled prompt string that fits within 4K tokens. Decides when to trigger summarization.
- **Views:** Pure SwiftUI. Use `@Query` for SwiftData reads. Delegate all AI work to services.

## Visual Design

### Theme

Dark-first, modern, sleek. Bold typography, vibrant gradient accents.

### Color Palette

| Role | Value |
|---|---|
| Background | `#0a0a0f` (near-black) |
| Card background | `#16162a` (dark navy) |
| Card border | `#2a2a4a` (subtle purple-grey) |
| Primary gradient | `#a78bfa → #ec4899` (violet to pink) |
| Violet accent | `#a78bfa` |
| Pink accent | `#ec4899` |
| Text primary | `#e2e8f0` |
| Text secondary | `#94a3b8` |
| Text muted | `#64748b` |

### Avatar Gradients

Predefined set of gradient pairs assigned to each woman profile:

1. Pink → Violet (`#f472b6 → #a78bfa`)
2. Green → Blue (`#34d399 → #3b82f6`)
3. Amber → Orange (`#fbbf24 → #f97316`)
4. Cyan → Indigo (`#22d3ee → #6366f1`)
5. Rose → Red (`#fb7185 → #ef4444`)

### Typography

- App title: 28pt, weight 800, gradient text
- Section headings: 17pt, weight 700
- Body text: 14pt, regular
- Labels/metadata: 11-12pt, secondary color

### Animations

- Response text: streaming typing animation (character by character)
- Tone picker: spring animation on selection
- Navigation: standard SwiftUI push transitions
- Generate button: subtle pulse while generating

## Out of Scope (MVP)

- Cloud API fallback
- Share sheet or keyboard extension
- Photo/image analysis
- Multiple response suggestions (single + regenerate only)
- Export or backup of conversations
- Onboarding tutorial
- Localization (English only)
- Widgets or Live Activities
- iPad or Mac support
- User accounts or sync
