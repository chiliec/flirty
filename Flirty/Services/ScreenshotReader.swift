import Foundation
import Vision

/// Pulls the text out of a chat screenshot, on device, so the user can drop a screenshot
/// in instead of retyping her message. Lines come back top to bottom; both sides of the
/// chat are included and the model is told to answer the latest message.
enum ScreenshotReader {
    static func text(in imageData: Data) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        let observations = try await request.perform(on: imageData)
        return
            observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
