# Flirty App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iOS 26 SwiftUI app that generates romantic/thoughtful chat responses using Apple's on-device Foundation Models framework.

**Architecture:** SwiftData for persistence (WomanProfile + Conversation models), ContextManager for token-budget-aware prompt assembly, AIService wrapping LanguageModelSession for streaming generation. Dark-themed UI with violet/pink gradient accents.

**Tech Stack:** Swift 6.2+, SwiftUI, SwiftData, FoundationModels (iOS 26), Xcode 26+

---

## File Structure

```
Flirty/
├── App/
│   └── FlirtyApp.swift                — Entry point, SwiftData container, availability check
├── Models/
│   ├── Tone.swift                     — Enum: flirty/sweet/funny/poetic/caring with display props
│   ├── WomanProfile.swift             — SwiftData @Model: name, notes, gradientIndex, summary
│   └── Conversation.swift             — SwiftData @Model: herMessage, userContext, tone, response
├── Services/
│   ├── AIService.swift                — Foundation Models session wrapper, streaming generation
│   └── ContextManager.swift           — Token budget logic, prompt assembly, summarization trigger
├── Theme/
│   └── AppTheme.swift                 — Colors, gradients, typography constants
├── Views/
│   ├── WomenListView.swift            — Home screen: profile cards, add button, swipe delete
│   ├── AddWomanView.swift             — Sheet: name + optional first note
│   ├── ChatView.swift                 — Main screen: history, input area, response display
│   ├── TonePicker.swift               — Horizontal pill selector component
│   ├── ResponseBubble.swift           — Single AI response with copy/regenerate actions
│   └── ProfileNotesView.swift         — Sheet: edit name, manage notes list
└── Resources/
    └── Assets.xcassets                 — App icon, color sets

FlirtyTests/
└── ContextManagerTests.swift          — Unit tests for prompt assembly and token budget
```

---

### Task 1: Create Xcode Project

**Files:**
- Create: `Flirty.xcodeproj` (via Xcode)
- Create: `Flirty/App/FlirtyApp.swift`

- [ ] **Step 1: Create the Xcode project**

Open Xcode and create a new project:
1. File → New → Project
2. Select "App" under iOS
3. Settings:
   - Product Name: `Flirty`
   - Organization Identifier: your reverse-domain (e.g., `com.yourname`)
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData
4. Save in `/Users/babin/Develop/Pet/flirty/`
5. Set minimum deployment target to iOS 26.0

- [ ] **Step 2: Clean up template files**

Delete the template files Xcode created (ContentView.swift, Item.swift) from the project navigator and filesystem:

```bash
rm Flirty/Item.swift Flirty/ContentView.swift
```

- [ ] **Step 3: Organize folder structure**

Create the directory structure inside `Flirty/`:

```bash
mkdir -p Flirty/App Flirty/Models Flirty/Services Flirty/Theme Flirty/Views
```

- [ ] **Step 4: Move and rewrite the app entry point**

Move `Flirty/FlirtyApp.swift` to `Flirty/App/FlirtyApp.swift` and replace its contents with a minimal shell:

```swift
import SwiftUI
import SwiftData

@main
struct FlirtyApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Flirty")
        }
        .modelContainer(for: [WomanProfile.self, Conversation.self])
    }
}
```

This won't compile yet — `WomanProfile` and `Conversation` don't exist. That's expected; we'll add them in the next task.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: create Xcode project skeleton with folder structure"
```

---

### Task 2: Theme Constants

**Files:**
- Create: `Flirty/Theme/AppTheme.swift`

- [ ] **Step 1: Create the theme file**

```swift
import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let background = Color(red: 0.039, green: 0.039, blue: 0.059)       // #0a0a0f
    static let cardBackground = Color(red: 0.086, green: 0.086, blue: 0.165)    // #16162a
    static let cardBorder = Color(red: 0.165, green: 0.165, blue: 0.290)        // #2a2a4a
    static let violet = Color(red: 0.655, green: 0.545, blue: 0.980)            // #a78bfa
    static let pink = Color(red: 0.925, green: 0.282, blue: 0.600)              // #ec4899
    static let textPrimary = Color(red: 0.886, green: 0.910, blue: 0.941)       // #e2e8f0
    static let textSecondary = Color(red: 0.580, green: 0.639, blue: 0.722)     // #94a3b8
    static let textMuted = Color(red: 0.392, green: 0.455, blue: 0.545)         // #64748b

    static let primaryGradient = LinearGradient(
        colors: [violet, pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Avatar Gradients
    static let avatarGradients: [(Color, Color)] = [
        (Color(red: 0.957, green: 0.447, blue: 0.714), Color(red: 0.655, green: 0.545, blue: 0.980)), // pink → violet
        (Color(red: 0.204, green: 0.827, blue: 0.600), Color(red: 0.231, green: 0.510, blue: 0.965)), // green → blue
        (Color(red: 0.984, green: 0.749, blue: 0.141), Color(red: 0.976, green: 0.451, blue: 0.086)), // amber → orange
        (Color(red: 0.133, green: 0.827, blue: 0.933), Color(red: 0.388, green: 0.400, blue: 0.945)), // cyan → indigo
        (Color(red: 0.984, green: 0.443, blue: 0.522), Color(red: 0.937, green: 0.267, blue: 0.267)), // rose → red
    ]

    static func avatarGradient(for index: Int) -> LinearGradient {
        let pair = avatarGradients[index % avatarGradients.count]
        return LinearGradient(
            colors: [pair.0, pair.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

Expected: Build will fail because FlirtyApp references missing models. That's fine — `AppTheme.swift` itself has no dependencies and will compile correctly as part of the module.

- [ ] **Step 3: Commit**

```bash
git add Flirty/Theme/AppTheme.swift
git commit -m "feat: add dark theme color palette and avatar gradients"
```

---

### Task 3: Data Models

**Files:**
- Create: `Flirty/Models/Tone.swift`
- Create: `Flirty/Models/WomanProfile.swift`
- Create: `Flirty/Models/Conversation.swift`

- [ ] **Step 1: Create the Tone enum**

```swift
import Foundation

enum Tone: String, Codable, CaseIterable, Identifiable {
    case flirty
    case sweet
    case funny
    case poetic
    case caring

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .flirty: "flame.fill"
        case .sweet: "heart.fill"
        case .funny: "face.smiling.fill"
        case .poetic: "sparkles"
        case .caring: "hands.and.sparkles.fill"
        }
    }

    var modifier: String {
        switch self {
        case .flirty: "Be playfully confident. Light teasing is good. Add subtle tension."
        case .sweet: "Be warm and affectionate. Show you care about the details she shares."
        case .funny: "Be witty and lighthearted. Use humor naturally, not forced jokes."
        case .poetic: "Be expressive and eloquent. Use vivid language and metaphors sparingly."
        case .caring: "Be supportive and attentive. Show empathy and genuine interest in her feelings."
        }
    }
}
```

- [ ] **Step 2: Create the WomanProfile model**

```swift
import Foundation
import SwiftData

@Model
final class WomanProfile {
    var id: UUID
    var name: String
    var gradientIndex: Int
    var notes: [String]
    var conversationSummary: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Conversation.womanProfile)
    var conversations: [Conversation]

    init(name: String, gradientIndex: Int, notes: [String] = []) {
        self.id = UUID()
        self.name = name
        self.gradientIndex = gradientIndex
        self.notes = notes
        self.conversationSummary = nil
        self.createdAt = Date()
        self.conversations = []
    }

    var initial: String {
        String(name.prefix(1)).uppercased()
    }

    var sortedConversations: [Conversation] {
        conversations.sorted { $0.createdAt < $1.createdAt }
    }

    var notesPreview: String {
        if notes.isEmpty { return "No notes yet" }
        return notes.joined(separator: ", ")
    }
}
```

- [ ] **Step 3: Create the Conversation model**

```swift
import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var herMessage: String
    var userContext: String?
    var toneRawValue: String
    var generatedResponse: String
    var createdAt: Date

    var womanProfile: WomanProfile?

    init(herMessage: String, userContext: String?, tone: Tone, generatedResponse: String) {
        self.id = UUID()
        self.herMessage = herMessage
        self.userContext = userContext
        self.toneRawValue = tone.rawValue
        self.generatedResponse = generatedResponse
        self.createdAt = Date()
    }

    var tone: Tone {
        get { Tone(rawValue: toneRawValue) ?? .sweet }
        set { toneRawValue = newValue.rawValue }
    }
}
```

- [ ] **Step 4: Verify the project compiles**

Now that models exist, update `FlirtyApp.swift` if needed and build:

```bash
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Flirty/Models/
git commit -m "feat: add Tone enum, WomanProfile and Conversation SwiftData models"
```

---

### Task 4: ContextManager with Tests

**Files:**
- Create: `Flirty/Services/ContextManager.swift`
- Create: `FlirtyTests/ContextManagerTests.swift`

- [ ] **Step 1: Write failing tests for ContextManager**

```swift
import Testing
@testable import Flirty

@Suite("ContextManager Tests")
struct ContextManagerTests {

    @Test("Builds prompt with all components")
    func buildPromptWithAllComponents() {
        let manager = ContextManager()
        let prompt = manager.buildPrompt(
            name: "Anna",
            notes: ["loves hiking", "has a cat named Milo"],
            tone: .sweet,
            herMessage: "Hey! How was your day?",
            userContext: "Had a great meeting today",
            recentExchanges: [],
            conversationSummary: nil
        )

        #expect(prompt.contains("Anna"))
        #expect(prompt.contains("loves hiking"))
        #expect(prompt.contains("has a cat named Milo"))
        #expect(prompt.contains("Hey! How was your day?"))
        #expect(prompt.contains("Had a great meeting today"))
        #expect(prompt.contains("sweet"))
        #expect(prompt.contains("warm and affectionate"))
    }

    @Test("Includes recent exchanges in prompt")
    func includesRecentExchanges() {
        let manager = ContextManager()
        let exchanges = [
            ContextManager.Exchange(herMessage: "Hi there!", response: "Hey! So nice to hear from you."),
            ContextManager.Exchange(herMessage: "What are you up to?", response: "Just thinking about our chat."),
        ]
        let prompt = manager.buildPrompt(
            name: "Sofia",
            notes: [],
            tone: .flirty,
            herMessage: "Haha you're sweet",
            userContext: nil,
            recentExchanges: exchanges,
            conversationSummary: nil
        )

        #expect(prompt.contains("Hi there!"))
        #expect(prompt.contains("Hey! So nice to hear from you."))
        #expect(prompt.contains("What are you up to?"))
        #expect(prompt.contains("Haha you're sweet"))
    }

    @Test("Includes conversation summary when provided")
    func includesConversationSummary() {
        let manager = ContextManager()
        let prompt = manager.buildPrompt(
            name: "Anna",
            notes: [],
            tone: .caring,
            herMessage: "I had a rough day",
            userContext: nil,
            recentExchanges: [],
            conversationSummary: "You've been chatting for a few days about travel plans."
        )

        #expect(prompt.contains("You've been chatting for a few days about travel plans."))
    }

    @Test("Omits user context section when nil")
    func omitsUserContextWhenNil() {
        let manager = ContextManager()
        let prompt = manager.buildPrompt(
            name: "Anna",
            notes: [],
            tone: .sweet,
            herMessage: "Hey!",
            userContext: nil,
            recentExchanges: [],
            conversationSummary: nil
        )

        #expect(!prompt.contains("Real context from user:"))
    }

    @Test("Estimates token count roughly as words * 1.3")
    func estimatesTokenCount() {
        let manager = ContextManager()
        let text = "Hello world this is a test"
        let estimate = manager.estimateTokens(text)
        // 6 words * 1.3 ≈ 8
        #expect(estimate >= 6)
        #expect(estimate <= 12)
    }

    @Test("Determines when summarization is needed")
    func summarizationNeeded() {
        let manager = ContextManager()

        // Short content — no summarization needed
        #expect(!manager.needsSummarization(
            notes: ["short note"],
            recentExchanges: [
                ContextManager.Exchange(herMessage: "Hi", response: "Hello!")
            ],
            conversationSummary: nil,
            herMessage: "Hey",
            userContext: nil
        ))
    }

    @Test("Trims exchanges when over budget")
    func trimsExchangesWhenOverBudget() {
        let manager = ContextManager()
        let longExchanges = (0..<20).map { i in
            ContextManager.Exchange(
                herMessage: "This is message number \(i) with some extra words to take up space in the token budget",
                response: "This is response number \(i) with additional padding text to simulate real conversation content"
            )
        }

        let trimmed = manager.trimExchanges(longExchanges, maxTokens: 400)
        #expect(trimmed.count < longExchanges.count)
        #expect(trimmed.count >= 1)
        // Should keep the most recent exchanges
        #expect(trimmed.last?.herMessage.contains("19") == true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | grep -E "(Test|error|FAIL)"
```

Expected: Compilation errors — `ContextManager` doesn't exist yet.

- [ ] **Step 3: Implement ContextManager**

```swift
import Foundation

struct ContextManager {

    struct Exchange {
        let herMessage: String
        let response: String
    }

    private let maxTotalTokens = 4096
    private let outputBudget = 600
    private let safetyMargin = 200
    private var inputBudget: Int { maxTotalTokens - outputBudget - safetyMargin }

    func buildPrompt(
        name: String,
        notes: [String],
        tone: Tone,
        herMessage: String,
        userContext: String?,
        recentExchanges: [Exchange],
        conversationSummary: String?
    ) -> String {
        var parts: [String] = []

        // System instructions
        parts.append("""
        You are a thoughtful assistant helping craft a message to \(name).
        Your response should sound natural — like something a real person
        would actually type in a chat. Match the tone: \(tone.displayName.lowercased()).

        Rules:
        - Write ONLY the message text, no labels or quotes
        - Keep it concise (2-4 sentences typically)
        - Be genuine, not cliche or over-the-top
        - Use the context provided — never invent facts about the user's life
        - Match the energy level of her message
        - If she asked a question, answer it using the user's real context

        \(tone.modifier)
        """)

        // Profile notes
        if !notes.isEmpty {
            parts.append("About her: \(notes.joined(separator: ", "))")
        }

        // Conversation summary
        if let summary = conversationSummary {
            parts.append("Previous conversation summary:\n\(summary)")
        }

        // Recent exchanges
        if !recentExchanges.isEmpty {
            var exchangeLines = "Recent messages:"
            for exchange in recentExchanges {
                exchangeLines += "\n  Her: \(exchange.herMessage)"
                exchangeLines += "\n  You replied: \(exchange.response)"
            }
            parts.append(exchangeLines)
        }

        // Current request
        parts.append("---\nHer new message: \(herMessage)")

        if let context = userContext, !context.isEmpty {
            parts.append("Real context from user: \(context)")
        }

        parts.append("Write a \(tone.displayName.lowercased()) response:")

        return parts.joined(separator: "\n\n")
    }

    func estimateTokens(_ text: String) -> Int {
        let words = text.split(separator: " ").count
        return max(1, Int(Double(words) * 1.3))
    }

    func needsSummarization(
        notes: [String],
        recentExchanges: [Exchange],
        conversationSummary: String?,
        herMessage: String,
        userContext: String?
    ) -> Bool {
        let prompt = buildPrompt(
            name: "X",
            notes: notes,
            tone: .sweet,
            herMessage: herMessage,
            userContext: userContext,
            recentExchanges: recentExchanges,
            conversationSummary: conversationSummary
        )
        return estimateTokens(prompt) > inputBudget
    }

    func trimExchanges(_ exchanges: [Exchange], maxTokens: Int) -> [Exchange] {
        var result: [Exchange] = []
        var tokenCount = 0

        for exchange in exchanges.reversed() {
            let exchangeTokens = estimateTokens(exchange.herMessage) + estimateTokens(exchange.response)
            if tokenCount + exchangeTokens > maxTokens && !result.isEmpty {
                break
            }
            result.insert(exchange, at: 0)
            tokenCount += exchangeTokens
        }

        return result
    }

    func buildSummarizationPrompt(exchanges: [Exchange]) -> String {
        var lines = "Summarize this conversation history in 2-3 sentences. Focus on: topics discussed, plans made, emotional tone, and personal details shared.\n\n"
        for exchange in exchanges {
            lines += "Her: \(exchange.herMessage)\n"
            lines += "He replied: \(exchange.response)\n\n"
        }
        return lines
    }

    func prepareContext(
        profile: WomanProfileData,
        herMessage: String,
        userContext: String?,
        tone: Tone
    ) -> (prompt: String, needsSummarization: Bool, exchangesToSummarize: [Exchange]) {
        let allExchanges = profile.exchanges
        var recentExchanges = Array(allExchanges.suffix(3))
        let olderExchanges = allExchanges.count > 3 ? Array(allExchanges.dropLast(3)) : []

        let shouldSummarize = !olderExchanges.isEmpty && profile.conversationSummary == nil

        // Trim recent exchanges if still over budget
        recentExchanges = trimExchanges(recentExchanges, maxTokens: 400)

        let prompt = buildPrompt(
            name: profile.name,
            notes: profile.notes,
            tone: tone,
            herMessage: herMessage,
            userContext: userContext,
            recentExchanges: recentExchanges,
            conversationSummary: profile.conversationSummary
        )

        return (prompt, shouldSummarize, olderExchanges)
    }
}

/// A lightweight data snapshot of WomanProfile for ContextManager (avoids SwiftData dependency).
struct WomanProfileData {
    let name: String
    let notes: [String]
    let conversationSummary: String?
    let exchanges: [ContextManager.Exchange]
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | grep -E "(Test|Passed|Failed)"
```

Expected: All 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Flirty/Services/ContextManager.swift FlirtyTests/ContextManagerTests.swift
git commit -m "feat: add ContextManager with token budget logic and prompt assembly"
```

---

### Task 5: AIService

**Files:**
- Create: `Flirty/Services/AIService.swift`

- [ ] **Step 1: Create the AIService**

```swift
import Foundation
import FoundationModels

@Generable
struct FlirtyResponse {
    @Guide(description: "The chat message response, 2-4 sentences, natural texting style")
    var message: String
}

enum AIAvailability {
    case available
    case notEnabled
    case notEligible
    case notReady
}

@Observable
final class AIService {
    private var session: LanguageModelSession?
    private let contextManager = ContextManager()

    var isGenerating = false

    func checkAvailability() -> AIAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return .available
        case .unavailable(.appleIntelligenceNotEnabled):
            return .notEnabled
        case .unavailable(.deviceNotEligible):
            return .notEligible
        case .unavailable(.modelNotReady):
            return .notReady
        @unknown default:
            return .notEligible
        }
    }

    func prewarm() {
        session = LanguageModelSession()
        session?.prewarm()
    }

    func createSession(instructions: String) {
        session = LanguageModelSession {
            Instructions(instructions)
        }
    }

    func generate(
        profile: WomanProfileData,
        herMessage: String,
        userContext: String?,
        tone: Tone,
        onUpdate: @escaping (String) -> Void,
        onSummarizationNeeded: ((String) async -> String?)? = nil
    ) async throws -> String {
        isGenerating = true
        defer { isGenerating = false }

        var profileData = profile

        // Check if summarization is needed
        let context = contextManager.prepareContext(
            profile: profileData,
            herMessage: herMessage,
            userContext: userContext,
            tone: tone
        )

        if context.needsSummarization, let summarize = onSummarizationNeeded {
            let summarizationPrompt = contextManager.buildSummarizationPrompt(
                exchanges: context.exchangesToSummarize
            )
            if let summary = await summarize(summarizationPrompt) {
                profileData = WomanProfileData(
                    name: profileData.name,
                    notes: profileData.notes,
                    conversationSummary: summary,
                    exchanges: profileData.exchanges
                )
            }
        }

        // Build the final prompt
        let finalContext = contextManager.prepareContext(
            profile: profileData,
            herMessage: herMessage,
            userContext: userContext,
            tone: tone
        )

        // Create a fresh session with system instructions
        let systemInstructions = contextManager.buildPrompt(
            name: profileData.name,
            notes: profileData.notes,
            tone: tone,
            herMessage: herMessage,
            userContext: userContext,
            recentExchanges: [],
            conversationSummary: profileData.conversationSummary
        )

        createSession(instructions: systemInstructions)

        guard let session else {
            throw AIServiceError.sessionNotAvailable
        }

        // Stream the response
        let stream = session.streamResponse(
            to: finalContext.prompt,
            generating: FlirtyResponse.self
        )

        var finalMessage = ""
        for try await partial in stream {
            if let message = partial.message {
                finalMessage = message
                onUpdate(message)
            }
        }

        return finalMessage
    }

    func summarize(prompt: String) async throws -> String {
        let summarySession = LanguageModelSession()
        let response = try await summarySession.respond(to: prompt)
        return response.content
    }
}

enum AIServiceError: LocalizedError {
    case sessionNotAvailable
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .sessionNotAvailable:
            "AI model session is not available."
        case .generationFailed(let reason):
            "Failed to generate response: \(reason)"
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED (the FoundationModels import is available in Xcode 26 SDK even when building for simulator).

- [ ] **Step 3: Commit**

```bash
git add Flirty/Services/AIService.swift
git commit -m "feat: add AIService with Foundation Models streaming generation"
```

---

### Task 6: WomenListView and AddWomanView

**Files:**
- Create: `Flirty/Views/WomenListView.swift`
- Create: `Flirty/Views/AddWomanView.swift`
- Modify: `Flirty/App/FlirtyApp.swift`

- [ ] **Step 1: Create WomenListView**

```swift
import SwiftUI
import SwiftData

struct WomenListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WomanProfile.createdAt, order: .reverse) private var profiles: [WomanProfile]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if profiles.isEmpty {
                    emptyState
                } else {
                    profileList
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Flirty")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(AppTheme.primaryGradient)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.primaryGradient)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddWomanView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.primaryGradient)
            Text("No conversations yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Tap + to add someone and start crafting\nthoughtful messages")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var profileList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(profiles) { profile in
                    NavigationLink(value: profile) {
                        profileCard(profile)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationDestination(for: WomanProfile.self) { profile in
            ChatView(profile: profile)
        }
    }

    private func profileCard(_ profile: WomanProfile) -> some View {
        HStack(spacing: 12) {
            Text(profile.initial)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(AppTheme.avatarGradient(for: profile.gradientIndex))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(profile.notesPreview)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(profile.conversations.count) chats")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func deleteProfile(_ profile: WomanProfile) {
        modelContext.delete(profile)
    }
}

#Preview {
    WomenListView()
        .modelContainer(for: [WomanProfile.self, Conversation.self], inMemory: true)
}
```

- [ ] **Step 2: Create AddWomanView**

```swift
import SwiftUI
import SwiftData

struct AddWomanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var firstNote = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Avatar preview
                    Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(AppTheme.primaryGradient)
                        .clipShape(Circle())
                        .padding(.top, 20)

                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        TextField("Her name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Optional first note
                    VStack(alignment: .leading, spacing: 6) {
                        Text("First note (optional)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        TextField("e.g., loves hiking, works in design", text: $firstNote)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(name.isEmpty ? AppTheme.textMuted : AppTheme.violet)
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        let notes = firstNote.isEmpty ? [] : [firstNote]
        let gradientIndex = Int.random(in: 0..<AppTheme.avatarGradients.count)
        let profile = WomanProfile(name: name.trimmingCharacters(in: .whitespaces), gradientIndex: gradientIndex, notes: notes)
        modelContext.insert(profile)
        dismiss()
    }
}

#Preview {
    AddWomanView()
        .modelContainer(for: [WomanProfile.self, Conversation.self], inMemory: true)
}
```

- [ ] **Step 3: Update FlirtyApp to use WomenListView as root**

```swift
import SwiftUI
import SwiftData

@main
struct FlirtyApp: App {
    var body: some Scene {
        WindowGroup {
            WomenListView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [WomanProfile.self, Conversation.self])
    }
}
```

- [ ] **Step 4: Build and verify previews render**

```bash
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED. Open Xcode and check SwiftUI previews for both views.

- [ ] **Step 5: Commit**

```bash
git add Flirty/Views/WomenListView.swift Flirty/Views/AddWomanView.swift Flirty/App/FlirtyApp.swift
git commit -m "feat: add WomenListView home screen and AddWomanView sheet"
```

---

### Task 7: TonePicker Component

**Files:**
- Create: `Flirty/Views/TonePicker.swift`

- [ ] **Step 1: Create the TonePicker**

```swift
import SwiftUI

struct TonePicker: View {
    @Binding var selectedTone: Tone

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Tone.allCases) { tone in
                    tonePill(tone)
                }
            }
        }
    }

    private func tonePill(_ tone: Tone) -> some View {
        let isSelected = selectedTone == tone

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTone = tone
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tone.icon)
                    .font(.system(size: 11))
                Text(tone.displayName)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? AnyShapeStyle(AppTheme.primaryGradient.opacity(0.2))
                    : AnyShapeStyle(AppTheme.cardBackground)
            )
            .foregroundStyle(isSelected ? AppTheme.pink : AppTheme.textMuted)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? AppTheme.pink.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        TonePicker(selectedTone: .constant(.sweet))
            .padding()
    }
}
```

- [ ] **Step 2: Build and verify preview**

```bash
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Flirty/Views/TonePicker.swift
git commit -m "feat: add TonePicker horizontal pill selector component"
```

---

### Task 8: ResponseBubble Component

**Files:**
- Create: `Flirty/Views/ResponseBubble.swift`

- [ ] **Step 1: Create the ResponseBubble view**

```swift
import SwiftUI

struct ResponseBubble: View {
    let tone: Tone
    let responseText: String
    let isStreaming: Bool
    var onCopy: () -> Void
    var onRegenerate: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tone label
            HStack(spacing: 4) {
                Image(systemName: tone.icon)
                    .font(.system(size: 10))
                Text("\(tone.displayName) response:")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(AppTheme.pink)

            // Response text
            Text(responseText)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textPrimary)
                .lineSpacing(4)
                .textSelection(.enabled)

            // Action buttons
            if !isStreaming {
                HStack(spacing: 8) {
                    Button {
                        onCopy()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12))
                            Text(copied ? "Copied" : "Copy")
                                .font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.cardBackground)
                        .foregroundStyle(AppTheme.violet)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onRegenerate()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12))
                            Text("Regenerate")
                                .font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.cardBackground)
                        .foregroundStyle(AppTheme.pink)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.102, green: 0.102, blue: 0.227),
                    Color(red: 0.165, green: 0.102, blue: 0.227)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.violet.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        ResponseBubble(
            tone: .sweet,
            responseText: "My day was actually really great — had one of those meetings where everything just clicks. But honestly, the best part of my evening is reading your message. How about we check out that cafe this Saturday? 😊",
            isStreaming: false,
            onCopy: {},
            onRegenerate: {}
        )
        .padding()
    }
}
```

- [ ] **Step 2: Build and verify preview**

```bash
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Flirty/Views/ResponseBubble.swift
git commit -m "feat: add ResponseBubble component with copy and regenerate actions"
```

---

### Task 9: ChatView — Main Interaction Screen

**Files:**
- Create: `Flirty/Views/ChatView.swift`

- [ ] **Step 1: Create ChatView**

```swift
import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    let profile: WomanProfile

    @State private var herMessage = ""
    @State private var userContext = ""
    @State private var selectedTone: Tone = .sweet
    @State private var currentResponse = ""
    @State private var isGenerating = false
    @State private var showingNotes = false
    @State private var showError = false
    @State private var errorMessage = ""

    @State private var aiService = AIService()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 12) {
                        conversationHistory
                        inputArea
                        if !currentResponse.isEmpty || isGenerating {
                            responseArea
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .onChange(of: currentResponse) {
                    withAnimation {
                        scrollProxy.scrollTo("bottom")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Text(profile.initial)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.avatarGradient(for: profile.gradientIndex))
                        .clipShape(Circle())
                    Text(profile.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNotes = true
                } label: {
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.violet)
                }
            }
        }
        .sheet(isPresented: $showingNotes) {
            ProfileNotesView(profile: profile)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            aiService.prewarm()
        }
    }

    // MARK: - Conversation History

    private var conversationHistory: some View {
        ForEach(profile.sortedConversations) { conversation in
            VStack(alignment: .leading, spacing: 8) {
                // Her message
                VStack(alignment: .leading, spacing: 2) {
                    Text("Her:")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textMuted)
                    Text(conversation.herMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(10)
                        .background(AppTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Your response
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: conversation.tone.icon)
                            .font(.system(size: 9))
                        Text("Your \(conversation.tone.displayName.lowercased()) reply:")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(AppTheme.textMuted)

                    Text(conversation.generatedResponse)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(10)
                        .background(AppTheme.violet.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 12) {
            // Her message input
            VStack(alignment: .leading, spacing: 4) {
                Text("Her message:")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textMuted)
                TextField("Paste her message here...", text: $herMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1...6)
                    .padding(12)
                    .background(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Tone picker
            TonePicker(selectedTone: $selectedTone)

            // User context input
            TextField("Add real context... (optional)", text: $userContext)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(12)
                .background(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Generate button
            Button {
                Task { await generateResponse() }
            } label: {
                HStack(spacing: 6) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                    }
                    Text(isGenerating ? "Generating..." : "Generate Response")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(herMessage.isEmpty || isGenerating ? AppTheme.cardBackground : AnyShapeStyle(AppTheme.primaryGradient))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(herMessage.isEmpty || isGenerating)
        }
    }

    // MARK: - Response Area

    private var responseArea: some View {
        ResponseBubble(
            tone: selectedTone,
            responseText: currentResponse.isEmpty ? "Thinking..." : currentResponse,
            isStreaming: isGenerating,
            onCopy: {
                UIPasteboard.general.string = currentResponse
            },
            onRegenerate: {
                Task { await generateResponse() }
            }
        )
    }

    // MARK: - Generation

    private func generateResponse() async {
        let messageText = herMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }

        isGenerating = true
        currentResponse = ""

        let profileData = WomanProfileData(
            name: profile.name,
            notes: profile.notes,
            conversationSummary: profile.conversationSummary,
            exchanges: profile.sortedConversations.map {
                ContextManager.Exchange(herMessage: $0.herMessage, response: $0.generatedResponse)
            }
        )

        let contextText = userContext.isEmpty ? nil : userContext

        do {
            let finalResponse = try await aiService.generate(
                profile: profileData,
                herMessage: messageText,
                userContext: contextText,
                tone: selectedTone,
                onUpdate: { partial in
                    currentResponse = partial
                },
                onSummarizationNeeded: { prompt in
                    try? await aiService.summarize(prompt: prompt)
                }
            )

            // Save the conversation
            let conversation = Conversation(
                herMessage: messageText,
                userContext: contextText,
                tone: selectedTone,
                generatedResponse: finalResponse
            )
            conversation.womanProfile = profile
            modelContext.insert(conversation)

            // Update summary if it was generated
            // (The summary is handled inside AIService)

            // Clear inputs for next round
            herMessage = ""
            userContext = ""

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isGenerating = false
    }
}

#Preview {
    NavigationStack {
        ChatView(profile: {
            let p = WomanProfile(name: "Anna", gradientIndex: 0, notes: ["loves hiking", "has a cat named Milo"])
            return p
        }())
    }
    .modelContainer(for: [WomanProfile.self, Conversation.self], inMemory: true)
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED (may warn about ProfileNotesView not yet existing — add a placeholder or proceed to Task 10).

- [ ] **Step 3: Commit**

```bash
git add Flirty/Views/ChatView.swift
git commit -m "feat: add ChatView with conversation history, input area, and AI generation"
```

---

### Task 10: ProfileNotesView

**Files:**
- Create: `Flirty/Views/ProfileNotesView.swift`

- [ ] **Step 1: Create ProfileNotesView**

```swift
import SwiftUI

struct ProfileNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: WomanProfile

    @State private var newNote = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Avatar
                    Text(profile.initial)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(AppTheme.avatarGradient(for: profile.gradientIndex))
                        .clipShape(Circle())
                        .padding(.top, 16)

                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        TextField("Name", text: $profile.name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)

                    // Notes section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notes about her")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)

                        // Existing notes
                        ForEach(Array(profile.notes.enumerated()), id: \.offset) { index, note in
                            HStack {
                                Text(note)
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Button {
                                    profile.notes.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(AppTheme.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Add new note
                        HStack(spacing: 8) {
                            TextField("Add a note...", text: $newNote)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(10)
                                .background(AppTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onSubmit { addNote() }

                            Button {
                                addNote()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(AppTheme.violet)
                            }
                            .buttonStyle(.plain)
                            .disabled(newNote.isEmpty)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.violet)
                }
            }
        }
    }

    private func addNote() {
        let trimmed = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profile.notes.append(trimmed)
        newNote = ""
    }
}

#Preview {
    ProfileNotesView(profile: WomanProfile(name: "Anna", gradientIndex: 0, notes: ["loves hiking", "has a cat named Milo"]))
        .modelContainer(for: [WomanProfile.self, Conversation.self], inMemory: true)
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Flirty/Views/ProfileNotesView.swift
git commit -m "feat: add ProfileNotesView sheet for editing name and notes"
```

---

### Task 11: Availability Check and App Polish

**Files:**
- Modify: `Flirty/App/FlirtyApp.swift`
- Modify: `Flirty/Views/WomenListView.swift`

- [ ] **Step 1: Add availability-aware root view to FlirtyApp**

Replace `Flirty/App/FlirtyApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct FlirtyApp: App {
    @State private var aiService = AIService()

    var body: some Scene {
        WindowGroup {
            RootView(aiService: aiService)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [WomanProfile.self, Conversation.self])
    }
}

struct RootView: View {
    let aiService: AIService
    @State private var availability: AIAvailability?

    var body: some View {
        Group {
            if let availability {
                switch availability {
                case .available:
                    WomenListView()
                case .notEnabled:
                    UnavailableView(
                        icon: "brain",
                        title: "Apple Intelligence Required",
                        message: "Enable Apple Intelligence in Settings → Apple Intelligence & Siri to use Flirty."
                    )
                case .notEligible:
                    UnavailableView(
                        icon: "iphone.slash",
                        title: "Device Not Supported",
                        message: "Flirty requires an iPhone that supports Apple Intelligence."
                    )
                case .notReady:
                    UnavailableView(
                        icon: "arrow.down.circle",
                        title: "AI Model Downloading",
                        message: "The AI model is still downloading. Please try again shortly.",
                        showRetry: true,
                        onRetry: checkAvailability
                    )
                }
            } else {
                ZStack {
                    AppTheme.background.ignoresSafeArea()
                    ProgressView()
                        .tint(AppTheme.violet)
                }
            }
        }
        .onAppear { checkAvailability() }
    }

    private func checkAvailability() {
        availability = aiService.checkAvailability()
    }
}

struct UnavailableView: View {
    let icon: String
    let title: String
    let message: String
    var showRetry = false
    var onRetry: (() -> Void)?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.primaryGradient)

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if showRetry, let onRetry {
                    Button("Try Again") { onRetry() }
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(AppTheme.primaryGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add swipe-to-delete in WomenListView**

In `Flirty/Views/WomenListView.swift`, replace the `profileList` computed property with a version that supports swipe-to-delete. Find:

```swift
    private var profileList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(profiles) { profile in
                    NavigationLink(value: profile) {
                        profileCard(profile)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationDestination(for: WomanProfile.self) { profile in
            ChatView(profile: profile)
        }
    }
```

Replace with:

```swift
    private var profileList: some View {
        List {
            ForEach(profiles) { profile in
                NavigationLink(value: profile) {
                    profileCardContent(profile)
                }
                .listRowBackground(AppTheme.cardBackground)
                .listRowSeparator(.hidden)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    modelContext.delete(profiles[index])
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationDestination(for: WomanProfile.self) { profile in
            ChatView(profile: profile)
        }
    }
```

And rename `profileCard` to `profileCardContent` (same content, just the inner HStack without the outer card background since List handles that):

```swift
    private func profileCardContent(_ profile: WomanProfile) -> some View {
        HStack(spacing: 12) {
            Text(profile.initial)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(AppTheme.avatarGradient(for: profile.gradientIndex))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(profile.notesPreview)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(profile.conversations.count) chats")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(.vertical, 4)
    }
```

Delete the old `profileCard` and `deleteProfile` methods.

- [ ] **Step 3: Build and verify**

```bash
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | grep -E "(Test|Passed|Failed|SUCCEEDED)"
```

Expected: All ContextManager tests pass, build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Flirty/App/FlirtyApp.swift Flirty/Views/WomenListView.swift
git commit -m "feat: add AI availability check, unavailable states, and swipe-to-delete"
```

---

### Task 12: End-to-End Manual Testing

**Files:** No file changes — this is a testing task.

- [ ] **Step 1: Launch on simulator or device**

```bash
xcodebuild -project Flirty.xcodeproj -scheme Flirty -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```

Open the simulator and run the app. If running on a physical device with Apple Intelligence, the AI features will work. On simulator, the availability check will likely show the "not eligible" or "not ready" state — this is expected.

- [ ] **Step 2: Test profile creation flow**

1. Tap "+" on home screen
2. Enter a name (verify Save button enables)
3. Optionally add a note
4. Tap Save — verify profile appears in list with correct initial, gradient, and notes preview

- [ ] **Step 3: Test profile notes editing**

1. Tap a profile to open ChatView
2. Tap the notes icon in the toolbar
3. Edit the name — verify it updates
4. Add and remove notes — verify the list updates
5. Dismiss and verify the home screen reflects changes

- [ ] **Step 4: Test chat input UI (simulator)**

1. Paste a message in "Her message" field
2. Select different tones — verify pill animation and selection state
3. Add optional context text
4. Verify Generate button enables when message is present and disables when empty

- [ ] **Step 5: Test AI generation (physical device only)**

On a device with Apple Intelligence enabled:
1. Create a profile with notes
2. Paste a message and select a tone
3. Add real context
4. Tap Generate — verify streaming response appears
5. Tap Copy — verify clipboard contains the response
6. Tap Regenerate — verify new response is generated
7. Verify conversation appears in history on next visit

- [ ] **Step 6: Test swipe-to-delete**

1. Swipe left on a profile in the home list
2. Tap Delete — verify profile and all its conversations are removed

- [ ] **Step 7: Commit any fixes**

If any bugs were found and fixed during testing:

```bash
git add -A
git commit -m "fix: address issues found during manual testing"
```

---

### Task 13: Verify post-MVP bug fixes on device

Added 2026-08-01. Steps 2, 3, 4 and 6 of Task 12 are now covered by the
automated UI suite (`-only-testing:FlirtyUITests`, 10 tests). The items below
are the ones that cannot be checked on the simulator: it has no Apple
Intelligence, and `--ui-testing` forces availability to `.available`.

**Update 2026-08-02 (`1211e3b`, `a72cb06`): the generation path is now
automated.** `FlirtyUITests/DeviceAIGenerationTests` runs against the real model
on hardware — 4/4 green on an iPhone 17e — covering streaming to completion,
copy confirmation, regeneration producing a fresh reply that is written back to
the stored exchange, and history surviving navigation. Run it with:

```bash
xcodebuild test -project Flirty.xcodeproj -scheme Flirty \
  -destination 'id=<device-udid>' \
  -only-testing:FlirtyUITests/DeviceAIGenerationTests
```

Writing those tests surfaced a bug no simulator test could have: **Regenerate was
completely dead** once a response had landed. It called `generateResponse()`,
which reads `herMessage` — cleared on success — behind a non-empty guard, so the
tap did nothing; and had the guard passed it would have appended a second
`Conversation` instead of replacing the reply. Fixed in `1211e3b` via
`regenerateLastResponse()`.

The four steps below remain and are genuinely manual — each needs a person
holding a conversation or toggling Settings.

- [x] **Step 1: Verify conversation summarization end-to-end** (fixes `b16c76e`)
      — **automated and green on device 2026-08-02**

Summaries were previously generated and thrown away — `conversationSummary`
was never written, so the model never saw history past the last 3 exchanges.

Covered by `DeviceAIGenerationTests.testSummarizationFoldsAgedOutExchangesIntoTheStoredSummary`
(45s, seven real generations). It reads state through the `--ui-testing`-only
`summaryDiagnostic` label in `ChatView`, since neither field is otherwise
observable outside a debugger, and asserts:

1. Nothing is summarized while all four stored exchanges still fit the verbatim
   window (`summarized:0`, empty summary)
2. The fifth generation ages out exchange 1 → `summarized:1` with a non-empty
   summary
3. That summary still carries exchange 1's content, so aged-out context is
   forwarded rather than lost
4. The sixth generation folds exchange 2 in → `summarized:2`, summary text
   changed (incremental refresh, not a stale summary)
5. Regeneration, which drops the replayed exchange from the history so nothing
   new ages out, leaves the diagnostic byte-identical — summarization does not
   re-run

Whether the *reply* visibly uses a summarized-away detail is a judgement call
and stays a printed observation, not an assertion; that the stored summary
reaches the prompt is covered by `ContextManagerTests`.

- [x] **Step 2: Verify the SwiftData migration** (fixes `b16c76e`)
      — **verified on device 2026-08-02**

`summarizedExchangeCount` was added to `WomanProfile` in `b16c76e`. Install over a
build that predates it and confirm existing profiles load.

**Low-risk by construction, then confirmed empirically.** The container is the
default `.modelContainer(for:)` in `FlirtyApp` — no `VersionedSchema` or
`SchemaMigrationPlan` — so SwiftData applies implicit lightweight migration. The
only schema delta from `09a6c18` (the last commit before `b16c76e`) is
`summarizedExchangeCount: Int = 0`, a single new non-optional but **defaulted**
`Int`; `conversationSummary: String?` already existed at `09a6c18`. A defaulted
non-optional satisfies lightweight migration's constraints.

Verified on the iPhone 17e: built `09a6c18` from a worktree, seeded a persistent
`MigrationTest` profile (a UI test relaunched **without** `--ui-testing` so it hit
the on-disk store, not the in-memory `--ui-testing` one), then `devicectl`
**upgrade-installed** the current build over it and launched. A temporary
launch-time diagnostic printed `[MigrationDiag] profiles=1` with no crash — the
old-schema store migrated in place and the existing profile loaded.

**Harness note for anyone re-running this.** `xcodebuild test` clean-installs the
app-under-test and **wipes the data container on every run** (proved directly: a
same-build seed-then-read lost the seeded profile). So the old→new store handoff
must be done with `devicectl device install app` (an upgrade install that
preserves data), *not* by running a second `xcodebuild test`. The seed and the
diagnostic were throwaway — reverted, not committed.

- [ ] **Step 3: Verify the availability gate recovers** (fixes `68d1e46`)

Expectations here were written before the `modelNotReady` finding and have been
corrected: with Apple Intelligence switched off, iOS 26 reports
`.unavailable(.modelNotReady)`, **not** `.appleIntelligenceNotEnabled`. The
screen to expect is therefore "AI Model Not Ready", not "Apple Intelligence
Required" — the latter may be unreachable on iOS 26. Verified on an iPhone 17e.

1. Disable Apple Intelligence in Settings, launch Flirty → "AI Model Not Ready"
2. Tap Try Again → screen stays (still disabled)
3. Tap Open Settings → lands on Flirty's own pane (`openSettingsURLString`
   cannot target system panes; the copy tells the user to navigate up to
   Apple Intelligence & Siri). Confirm the copy reads correctly.
4. Enable Apple Intelligence in Settings, return to Flirty **without force-quitting**
5. Confirm the app moves to the main list on its own via the `scenePhase` re-check
6. While the model is genuinely downloading, confirm the 15s poll added in
   `4ef8026` clears the gate with no user action at all

- [x] **Step 4: Verify generation error messages** (fixes `222ea93`)
      — **automated and green on device 2026-08-02**

`222ea93` maps every `GenerationError` case to user-facing text. Guardrail
violations are the easiest to trigger deliberately — the alert must read as the
plain guardrail message, with no "Failed to generate response:" prefix.

Covered by `DeviceAIGenerationTests.testGuardrailViolationShowsPlainMessageWithoutTheErrorPrefix`
(17s — the input guardrail fires before any generation runs). A deliberately
violent fixture message trips Apple's input guardrail; the test then asserts the
"Error" alert body BEGINSWITH the guardrail copy and does **not** contain
"Failed to generate response:". Because only `.guardrailViolation` maps to
`.guardrailBlocked` (a model `.refusal` maps to the prefixed `.generationFailed`),
the absence-of-prefix check also proves the guardrail and refusal paths stay
distinct. The fixture is violent rather than sexual: the most reliable non-sexual
input-guardrail trigger, and it keeps the committed test clinical.

Only Steps 2 (SwiftData migration) and 3 (availability-gate recovery) remain
manual — both need sequential installs or Settings toggling that XCUITest cannot
drive.

---

## Open design question

Resolved 2026-08-01 (`5c4230e`): deleted `ContextManager.needsSummarization`
(the 4096-token budget check) along with its now-unused supporting constants.
It had no production caller — summarization is triggered purely by the
aged-exchange-count tracking (`summarizedExchangeCount`) added in `b16c76e`,
and prompt size is bounded by the fixed `recentExchangeBudget` /
`summarizationInputBudget` trims, well under the 4096 total.
