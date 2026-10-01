import Foundation

/// Where the cloud tier sends requests. Read from Info.plist keys the build fills in
/// from `Config/Secrets.xcconfig`; nil when no key was built in (CI, fresh clones),
/// which keeps the app on-device only.
struct GatewayConfig: Equatable, Sendable {
    static let defaultModel = "claude-haiku-4-5"

    let baseURL: URL
    let apiKey: String
    let model: String

    static func fromBundle(_ bundle: Bundle = .main) -> GatewayConfig? {
        GatewayConfig(info: bundle.infoDictionary ?? [:])
    }

    init(baseURL: URL, apiKey: String, model: String = GatewayConfig.defaultModel) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }

    init?(info: [String: Any]) {
        guard let key = Self.value(info["FLGatewayKey"]),
              let raw = Self.value(info["FLGatewayURL"]),
              let url = URL(string: raw), url.scheme == "https"
        else { return nil }
        self.init(baseURL: url, apiKey: key, model: Self.value(info["FLGatewayModel"]) ?? Self.defaultModel)
    }

    /// Empty or unexpanded (`$(VAR)`) build settings count as absent.
    private static func value(_ raw: Any?) -> String? {
        guard let s = (raw as? String)?.trimmingCharacters(in: .whitespaces), !s.isEmpty, !s.hasPrefix("$(")
        else { return nil }
        return s
    }
}

/// Streams replies from the Flirty gateway (Anthropic `/v1/messages` format) on devices
/// without Apple Intelligence. The only file in the app that touches the network.
struct GatewayClient: Sendable {
    let config: GatewayConfig
    var session: URLSession = .shared

    /// Yields the accumulated text so far, not deltas — the same contract as the
    /// on-device partial snapshots, so `AIService` callers see no difference.
    func stream(instructions: String?, prompt: String) -> AsyncThrowingStream<String, Error> {
        let request = makeRequest(instructions: instructions, prompt: prompt)
        let session = session
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard (200..<300).contains(status) else {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        throw Self.httpError(status: status, body: body)
                    }
                    // `lines` drops blank lines, so SSE frame boundaries are invisible
                    // here; each Anthropic `data:` payload carries its own `type`.
                    var text = ""
                    for try await line in bytes.lines {
                        switch Self.step(forLine: line) {
                        case .text(let delta):
                            text += delta
                            continuation.yield(text)
                        case .stop:
                            continuation.finish()
                            return
                        case .fail(let error): throw error
                        case .ignore: continue
                        }
                    }
                    throw AIServiceError.generationFailed("Connection interrupted")
                } catch {
                    continuation.finish(throwing: Self.mapped(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeRequest(instructions: String?, prompt: String) -> URLRequest {
        var request = URLRequest(url: config.baseURL.appending(path: "v1/messages"), timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body = RequestBody(
            model: config.model, system: instructions, messages: [.init(role: "user", content: prompt)])
        request.httpBody = try? JSONEncoder().encode(body)
        return request
    }

    // MARK: - Parsing

    enum Step: Equatable {
        case text(String)
        case stop
        case fail(AIServiceError)
        case ignore
    }

    static func step(forLine line: String) -> Step {
        guard line.hasPrefix("data:") else { return .ignore }
        let json = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        guard let event = try? JSONDecoder().decode(Event.self, from: Data(json.utf8)) else {
            return .fail(.generationFailed("Failed to parse the AI response. Please try again."))
        }
        switch event.type {
        case "content_block_delta":
            guard event.delta?.type == "text_delta", let text = event.delta?.text else { return .ignore }
            return .text(text)
        case "message_delta":
            return event.delta?.stopReason == "refusal"
                ? .fail(.generationFailed("The AI declined to generate a response. Try rephrasing or changing the tone."))
                : .ignore
        case "message_stop":
            return .stop
        case "error":
            return .fail(apiError(type: event.error?.type ?? "", message: event.error?.message ?? ""))
        default:
            return .ignore
        }
    }

    // MARK: - Error mapping

    static func httpError(status: Int, body: String) -> AIServiceError {
        switch status {
        case 401, 403: return .generationFailed("Gateway auth failed")
        case 402, 429, 529: return .generationFailed("Too many requests. Please wait a moment and try again.")
        case 413: return .generationFailed("The conversation is too long. Try clearing some history.")
        case 400:
            let lowered = body.lowercased()
            if lowered.contains("token") || lowered.contains("context") {
                return .generationFailed("The conversation is too long. Try clearing some history.")
            }
            return .generationFailed("HTTP 400")
        default: return .generationFailed("HTTP \(status)")
        }
    }

    private static func apiError(type: String, message: String) -> AIServiceError {
        switch type {
        case "rate_limit_error", "overloaded_error":
            return .generationFailed("Too many requests. Please wait a moment and try again.")
        case "request_too_large":
            return .generationFailed("The conversation is too long. Try clearing some history.")
        default:
            return .generationFailed(type.isEmpty ? message : type)
        }
    }

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
        .timedOut, .dataNotAllowed, .secureConnectionFailed,
    ]

    private static func mapped(_ error: Error) -> Error {
        if error is AIServiceError || error is CancellationError { return error }
        if let urlError = error as? URLError {
            if urlError.code == .cancelled { return CancellationError() }
            if offlineCodes.contains(urlError.code) { return AIServiceError.offline }
        }
        return AIServiceError.generationFailed(error.localizedDescription)
    }

    // MARK: - Wire types

    private struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        let model: String
        let stream = true
        let maxTokens = 1024
        let system: String?
        let messages: [Message]

        enum CodingKeys: String, CodingKey {
            case model, stream, system, messages
            case maxTokens = "max_tokens"
        }
    }

    private struct Event: Decodable {
        struct Delta: Decodable {
            let type: String?
            let text: String?
            let stopReason: String?

            enum CodingKeys: String, CodingKey {
                case type, text
                case stopReason = "stop_reason"
            }
        }
        struct APIError: Decodable {
            let type: String
            let message: String?
        }
        let type: String
        let delta: Delta?
        let error: APIError?
    }
}
