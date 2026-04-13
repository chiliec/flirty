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
}
