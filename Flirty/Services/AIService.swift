import Foundation
import FoundationModels

@Generable
struct FlirtyResponse {
    @Guide(description: "The chat message response, 2-4 sentences, natural texting style")
    var message: String
}

enum AIAvailability: Equatable, Sendable {
    case available
    case notEnabled
    case notEligible
    case notReady
}

@MainActor
@Observable
final class AIService {
    private var session: LanguageModelSession?
    private let contextManager = ContextManager()

    var isGenerating = false

    /// The three unavailable reasons are documented as distinct, but they are not in
    /// practice: on a device with Apple Intelligence switched *off* in Settings, iOS can
    /// still report `.modelNotReady` rather than `.appleIntelligenceNotEnabled`. Callers
    /// must therefore treat `.notReady` as "off or downloading", not "downloading".
    func checkAvailability() -> AIAvailability {
        let model = SystemLanguageModel.default
        #if DEBUG
        print("[Flirty] availability: \(availabilityDiagnostic)")
        #endif
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

    /// Raw framework value, for on-device debugging. Availability bugs cannot be
    /// reproduced on simulator, so the gate surfaces this string in DEBUG builds.
    var availabilityDiagnostic: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            "available"
        case .unavailable(let reason):
            "unavailable(\(reason))"
        @unknown default:
            "unrecognized availability value"
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
        onSummaryProduced: (@MainActor (String, Int) -> Void)? = nil
    ) async throws -> String {
        isGenerating = true
        defer { isGenerating = false }

        var profileData = profile

        // Fold any newly aged-out exchanges into the stored summary before prompting.
        let context = contextManager.prepareContext(
            profile: profileData,
            herMessage: herMessage,
            userContext: userContext,
            tone: tone
        )

        if context.needsSummarization {
            let summarizationPrompt = contextManager.buildSummarizationPrompt(
                previousSummary: profileData.conversationSummary,
                exchanges: context.exchangesToSummarize
            )
            // A failed summarization is not fatal — fall back to the previous summary.
            if let summary = try? await summarize(prompt: summarizationPrompt) {
                profileData = WomanProfileData(
                    name: profileData.name,
                    notes: profileData.notes,
                    conversationSummary: summary,
                    summarizedExchangeCount: context.summarizedThroughCount,
                    exchanges: profileData.exchanges
                )
                onSummaryProduced?(summary, context.summarizedThroughCount)
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
        do {
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
        } catch let error as LanguageModelSession.GenerationError {
            throw Self.mapGenerationError(error)
        } catch let error as AIServiceError {
            throw error
        } catch {
            // Catch model catalog / asset errors that aren't typed as GenerationError
            let description = error.localizedDescription
            if description.contains("modelcatalog") || description.contains("UnifiedAssetFramework") {
                throw AIServiceError.modelNotDownloaded
            }
            throw AIServiceError.generationFailed(description)
        }
    }

    private static func mapGenerationError(_ error: LanguageModelSession.GenerationError) -> AIServiceError {
        switch error {
        case .guardrailViolation:
            return .guardrailBlocked
        case .assetsUnavailable:
            return .modelNotDownloaded
        case .exceededContextWindowSize:
            return .generationFailed("The conversation is too long. Try clearing some history.")
        case .rateLimited:
            return .generationFailed("Too many requests. Please wait a moment and try again.")
        case .concurrentRequests:
            return .generationFailed("Another request is in progress. Please wait for it to finish.")
        case .unsupportedLanguageOrLocale:
            return .generationFailed("Your current language or region isn't supported by the AI model.")
        case .unsupportedGuide:
            return .generationFailed("Response format error. Please try again.")
        case .decodingFailure:
            return .generationFailed("Failed to parse the AI response. Please try again.")
        case .refusal:
            return .generationFailed("The AI declined to generate a response. Try rephrasing or changing the tone.")
        @unknown default:
            return .generationFailed(error.localizedDescription)
        }
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
    case modelNotDownloaded
    case guardrailBlocked

    var errorDescription: String? {
        switch self {
        case .sessionNotAvailable:
            "AI model session is not available."
        case .generationFailed(let reason):
            "Failed to generate response: \(reason)"
        case .modelNotDownloaded:
            "The AI model is still downloading. Go to Settings → Apple Intelligence & Siri and make sure the download is complete, then try again."
        case .guardrailBlocked:
            "Apple's content policy prevented generating this response. Try a different tone or rephrase the context."
        }
    }
}
