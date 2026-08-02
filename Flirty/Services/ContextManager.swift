import Foundation

struct ContextManager {

    struct Exchange {
        let herMessage: String
        let response: String
    }

    /// The most recent exchanges are always sent verbatim; older ones get summarized.
    static let verbatimExchangeCount = 3

    private let recentExchangeBudget = 400
    private let summarizationInputBudget = 1200

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

    /// Keeps the most *recent* exchanges within budget — the verbatim window, where the
    /// latest messages matter most. Drops from the front.
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

    /// Keeps the *oldest* exchanges within budget, contiguous from the front. The
    /// summarization batch must stay flush against what the stored summary already
    /// covers: whatever this returns is exactly what gets folded in, and the persisted
    /// count advances by its length — so dropping from the *back* (unlike the verbatim
    /// window) leaves the newer, still-unsummarized exchanges for the next pass instead
    /// of marking them covered and losing them.
    func trimOldestExchanges(_ exchanges: [Exchange], maxTokens: Int) -> [Exchange] {
        var result: [Exchange] = []
        var tokenCount = 0

        for exchange in exchanges {
            let exchangeTokens = estimateTokens(exchange.herMessage) + estimateTokens(exchange.response)
            if tokenCount + exchangeTokens > maxTokens && !result.isEmpty {
                break
            }
            result.append(exchange)
            tokenCount += exchangeTokens
        }

        return result
    }

    /// Builds an incremental summarization prompt: the summary produced so far plus
    /// only the exchanges that have aged out since it was written.
    func buildSummarizationPrompt(previousSummary: String?, exchanges: [Exchange]) -> String {
        var lines = "Summarize this conversation history in 2-3 sentences. Focus on: topics discussed, plans made, emotional tone, and personal details shared.\n\n"

        if let previousSummary, !previousSummary.isEmpty {
            lines += "Summary of the conversation so far:\n\(previousSummary)\n\n"
            lines += "Fold these newer messages into that summary:\n\n"
        }

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

    struct PreparedContext {
        let prompt: String
        let needsSummarization: Bool
        /// Only the exchanges that aged out since the stored summary was written.
        let exchangesToSummarize: [Exchange]
        /// Total aged-out exchanges a new summary would cover; persist alongside it.
        let summarizedThroughCount: Int
    }

    func prepareContext(
        profile: WomanProfileData,
        herMessage: String,
        userContext: String?,
        tone: Tone
    ) -> PreparedContext {
        let allExchanges = profile.exchanges
        let olderExchanges = allExchanges.count > Self.verbatimExchangeCount
            ? Array(allExchanges.dropLast(Self.verbatimExchangeCount))
            : []

        // Exchanges already folded into the stored summary stay folded in — only the
        // ones that aged out since then need another summarization pass. Without this
        // the summary would be rebuilt from scratch (or never refreshed) every time.
        let alreadySummarized = min(max(profile.summarizedExchangeCount, 0), olderExchanges.count)
        let newlyAged = trimOldestExchanges(
            Array(olderExchanges.dropFirst(alreadySummarized)),
            maxTokens: summarizationInputBudget
        )

        let recentExchanges = trimExchanges(
            Array(allExchanges.suffix(Self.verbatimExchangeCount)),
            maxTokens: recentExchangeBudget
        )

        let prompt = buildPrompt(
            name: profile.name,
            notes: profile.notes,
            tone: tone,
            herMessage: herMessage,
            userContext: userContext,
            recentExchanges: recentExchanges,
            conversationSummary: profile.conversationSummary
        )

        return PreparedContext(
            prompt: prompt,
            needsSummarization: !newlyAged.isEmpty,
            exchangesToSummarize: newlyAged,
            // Only count what was actually summarized. If the budget dropped the tail of
            // the batch, those exchanges stay uncovered for the next pass rather than
            // being silently marked folded-in.
            summarizedThroughCount: alreadySummarized + newlyAged.count
        )
    }
}

/// A lightweight data snapshot of WomanProfile for ContextManager (avoids SwiftData dependency).
struct WomanProfileData {
    let name: String
    let notes: [String]
    let conversationSummary: String?
    /// How many aged-out exchanges `conversationSummary` already covers.
    let summarizedExchangeCount: Int
    let exchanges: [ContextManager.Exchange]

    init(
        name: String,
        notes: [String],
        conversationSummary: String?,
        summarizedExchangeCount: Int = 0,
        exchanges: [ContextManager.Exchange]
    ) {
        self.name = name
        self.notes = notes
        self.conversationSummary = conversationSummary
        self.summarizedExchangeCount = summarizedExchangeCount
        self.exchanges = exchanges
    }
}
