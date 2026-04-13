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

    func buildInstructions(name: String, tone: Tone) -> String {
        """
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
        """
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
