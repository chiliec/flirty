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
        #expect(estimate >= 6)
        #expect(estimate <= 12)
    }

    @Test("Determines when summarization is needed")
    func summarizationNeeded() {
        let manager = ContextManager()

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
}
