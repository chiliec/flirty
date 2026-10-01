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

        #expect(prompt.contains("loves hiking"))
        #expect(prompt.contains("has a cat named Milo"))
        #expect(prompt.contains("Hey! How was your day?"))
        #expect(prompt.contains("Had a great meeting today"))
        #expect(prompt.contains("sweet"))
        // The persona lives in the session instructions, not the prompt — sending it
        // twice wasted budget.
        #expect(!prompt.contains("Rules:"))
        let instructions = manager.buildInstructions(name: "Anna", tone: .sweet)
        #expect(instructions.contains("Anna"))
        #expect(instructions.contains("warm and affectionate"))
        #expect(instructions.contains("Reply in the language she wrote in"))
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
        #expect(estimate >= 6)
        #expect(estimate <= 12)
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
        #expect(trimmed.last?.herMessage.contains("19") == true)
    }

    // MARK: - Summarization coverage

    private func profile(
        exchangeCount: Int,
        summary: String? = nil,
        summarizedExchangeCount: Int = 0
    ) -> WomanProfileData {
        WomanProfileData(
            name: "Anna",
            notes: [],
            conversationSummary: summary,
            summarizedExchangeCount: summarizedExchangeCount,
            exchanges: (0..<exchangeCount).map {
                ContextManager.Exchange(herMessage: "Her message \($0)", response: "Reply \($0)")
            }
        )
    }

    @Test("Skips summarization while every exchange still fits verbatim")
    func noSummarizationWithinVerbatimWindow() {
        let manager = ContextManager()
        let context = manager.prepareContext(
            profile: profile(exchangeCount: ContextManager.verbatimExchangeCount),
            herMessage: "Hey",
            userContext: nil,
            tone: .sweet
        )

        #expect(!context.needsSummarization)
        #expect(context.summarizedThroughCount == 0)
    }

    @Test("Summarizes exchanges that age out of the verbatim window")
    func summarizesAgedOutExchanges() {
        let manager = ContextManager()
        let context = manager.prepareContext(
            profile: profile(exchangeCount: 5),
            herMessage: "Hey",
            userContext: nil,
            tone: .sweet
        )

        // 5 exchanges, last 3 verbatim, so the first 2 age out.
        #expect(context.needsSummarization)
        #expect(context.summarizedThroughCount == 2)
        #expect(context.exchangesToSummarize.count == 2)
        #expect(context.exchangesToSummarize.first?.herMessage == "Her message 0")
    }

    @Test("Does not re-summarize exchanges the stored summary already covers")
    func skipsAlreadySummarizedExchanges() {
        let manager = ContextManager()
        let context = manager.prepareContext(
            profile: profile(exchangeCount: 5, summary: "Earlier chat.", summarizedExchangeCount: 2),
            herMessage: "Hey",
            userContext: nil,
            tone: .sweet
        )

        // Regression guard: this was an unconditional re-summarization on every generation.
        #expect(!context.needsSummarization)
        #expect(context.exchangesToSummarize.isEmpty)
    }

    @Test("Refreshes the summary when new exchanges age out past it")
    func refreshesSummaryAsConversationGrows() {
        let manager = ContextManager()
        let context = manager.prepareContext(
            profile: profile(exchangeCount: 7, summary: "Earlier chat.", summarizedExchangeCount: 2),
            herMessage: "Hey",
            userContext: nil,
            tone: .sweet
        )

        // 7 exchanges → 4 aged out, 2 already covered, so exactly 2 are new.
        #expect(context.needsSummarization)
        #expect(context.summarizedThroughCount == 4)
        #expect(context.exchangesToSummarize.count == 2)
        #expect(context.exchangesToSummarize.first?.herMessage == "Her message 2")
    }

    @Test("Counts only the exchanges the budget actually let it summarize")
    func summarizationCountReflectsBudgetTruncation() {
        let manager = ContextManager()
        // Each exchange is deliberately large, so the aged-out batch overflows the
        // summarization budget and only a prefix of it can be folded in this pass.
        let filler = String(repeating: "word ", count: 90)
        let exchanges = (0..<15).map {
            ContextManager.Exchange(herMessage: "Her \($0) \(filler)", response: "Reply \($0) \(filler)")
        }
        let context = manager.prepareContext(
            profile: WomanProfileData(name: "Anna", notes: [], conversationSummary: nil, exchanges: exchanges),
            herMessage: "Hey",
            userContext: nil,
            tone: .sweet
        )

        // 15 exchanges → 12 age out of the verbatim window, but the budget admits fewer.
        #expect(context.needsSummarization)
        #expect(context.exchangesToSummarize.count < 12)
        // The count must match what was summarized, not the full aged-out set, and must
        // start from the oldest so the tail stays uncovered for the next pass.
        #expect(context.summarizedThroughCount == context.exchangesToSummarize.count)
        #expect(context.exchangesToSummarize.first?.herMessage.hasPrefix("Her 0 ") == true)
    }

    @Test("Folds the previous summary into an incremental summarization prompt")
    func summarizationPromptCarriesPreviousSummary() {
        let manager = ContextManager()
        let prompt = manager.buildSummarizationPrompt(
            previousSummary: "You discussed travel plans.",
            exchanges: [ContextManager.Exchange(herMessage: "Booked it!", response: "Amazing!")]
        )

        #expect(prompt.contains("You discussed travel plans."))
        #expect(prompt.contains("Booked it!"))
    }

    @Test("Includes the stored summary in the generation prompt")
    func preparedPromptIncludesStoredSummary() {
        let manager = ContextManager()
        let context = manager.prepareContext(
            profile: profile(exchangeCount: 5, summary: "Earlier chat about hiking.", summarizedExchangeCount: 2),
            herMessage: "Hey",
            userContext: nil,
            tone: .sweet
        )

        #expect(context.prompt.contains("Earlier chat about hiking."))
    }

    // MARK: - Token estimation

    @Test("Counts words across any whitespace, not just spaces")
    func estimatesTokensAcrossWhitespace() {
        let manager = ContextManager()
        // The same seven words, joined by spaces vs. the newlines/tabs that stitch prompt
        // segments together. A space-only split fused "hello\nYou" into one word and
        // undercounted; the estimate must not depend on which whitespace separates words.
        let spaced = "Her hello You replied hey there friend"
        let mixed = "Her hello\nYou replied\they there friend"
        #expect(manager.estimateTokens(spaced) == manager.estimateTokens(mixed))
    }

    @Test("Estimates at least one token for empty or whitespace-only text")
    func estimatesMinimumTokenFloor() {
        let manager = ContextManager()
        #expect(manager.estimateTokens("") == 1)
        #expect(manager.estimateTokens("   \n\t ") == 1)
    }

    // MARK: - Directional trimming

    @Test("trimExchanges keeps the newest, trimOldestExchanges keeps the oldest")
    func directionalTrimming() {
        let manager = ContextManager()
        // Each exchange is ~4 estimated tokens ("Her N" + "Reply N", two words each), so a
        // 12-token budget admits exactly three.
        let exchanges = (0..<6).map {
            ContextManager.Exchange(herMessage: "Her \($0)", response: "Reply \($0)")
        }

        let newest = manager.trimExchanges(exchanges, maxTokens: 12)
        let oldest = manager.trimOldestExchanges(exchanges, maxTokens: 12)

        #expect(newest.count == 3)
        #expect(oldest.count == 3)
        // trimExchanges drops from the front (older end); trimOldestExchanges drops from the
        // back (newer end). Same budget, opposite survivors — the whole point of the split.
        #expect(newest.first?.herMessage == "Her 3")
        #expect(newest.last?.herMessage == "Her 5")
        #expect(oldest.first?.herMessage == "Her 0")
        #expect(oldest.last?.herMessage == "Her 2")
    }

    @Test("Both trims keep at least one exchange even when it exceeds the budget")
    func keepsAtLeastOneOverBudgetExchange() {
        let manager = ContextManager()
        let oversized = ContextManager.Exchange(
            herMessage: String(repeating: "word ", count: 100),
            response: String(repeating: "word ", count: 100)
        )
        #expect(manager.trimExchanges([oversized], maxTokens: 10).count == 1)
        #expect(manager.trimOldestExchanges([oversized], maxTokens: 10).count == 1)
    }

    // MARK: - Stored-count clamping

    @Test("Clamps a stored summary count that exceeds the aged-out exchanges")
    func clampsOverlargeSummarizedCount() {
        let manager = ContextManager()
        // 5 exchanges → only 2 age out of the verbatim window, but a corrupt stored count
        // claims 99 are already summarized. It must clamp, not drop past the front.
        let context = manager.prepareContext(
            profile: profile(exchangeCount: 5, summary: "Old.", summarizedExchangeCount: 99),
            herMessage: "Hey",
            userContext: nil,
            tone: .sweet
        )

        #expect(!context.needsSummarization)
        #expect(context.exchangesToSummarize.isEmpty)
        #expect(context.summarizedThroughCount == 2)
    }

    @Test("Treats a negative stored summary count as zero")
    func clampsNegativeSummarizedCount() {
        let manager = ContextManager()
        let context = manager.prepareContext(
            profile: profile(exchangeCount: 5, summarizedExchangeCount: -3),
            herMessage: "Hey",
            userContext: nil,
            tone: .sweet
        )

        // Behaves as if nothing was summarized: both aged-out exchanges are fresh.
        #expect(context.needsSummarization)
        #expect(context.summarizedThroughCount == 2)
        #expect(context.exchangesToSummarize.count == 2)
        #expect(context.exchangesToSummarize.first?.herMessage == "Her message 0")
    }

    @Test("Omits the fold-in header when there is no previous summary")
    func summarizationPromptWithoutPreviousSummary() {
        let manager = ContextManager()
        let exchange = ContextManager.Exchange(herMessage: "Hi", response: "Hey")

        for previous in [nil, ""] as [String?] {
            let prompt = manager.buildSummarizationPrompt(previousSummary: previous, exchanges: [exchange])
            #expect(!prompt.contains("Summary of the conversation so far"))
            #expect(!prompt.contains("Fold these newer messages"))
            #expect(prompt.contains("Hi"))
        }
    }
}
