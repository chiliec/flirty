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

    func generate(
        profile: WomanProfileData,
        herMessage: String,
        userContext: String?,
        tone: Tone,
        onUpdate: @escaping @MainActor (String) -> Void,
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

        // Build the final prompt with potentially updated summary
        let finalContext = contextManager.prepareContext(
            profile: profileData,
            herMessage: herMessage,
            userContext: userContext,
            tone: tone
        )

        // Create a fresh session with system instructions
        let instructions = contextManager.buildInstructions(name: profileData.name, tone: tone)
        session = LanguageModelSession {
            instructions
        }

        guard let session else {
            throw AIServiceError.sessionNotAvailable
        }

        // Stream the response
        let stream = session.streamResponse(to: finalContext.prompt, generating: FlirtyResponse.self)

        var finalMessage = ""
        for try await partial in stream {
            if let message = partial.content.message {
                finalMessage = message
                await onUpdate(message)
            }
        }

        if finalMessage.isEmpty {
            throw AIServiceError.generationFailed("Empty response from model")
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
