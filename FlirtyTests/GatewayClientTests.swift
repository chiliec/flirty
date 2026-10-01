import Foundation
import Testing
@testable import Flirty

@Suite("GatewayConfig")
struct GatewayConfigTests {
    @Test func readsAllKeys() {
        let config = GatewayConfig(info: [
            "FLGatewayURL": "https://gateway.example.com",
            "FLGatewayKey": "sk-axv-123",
            "FLGatewayModel": "claude-x",
        ])
        #expect(
            config == GatewayConfig(
                baseURL: URL(string: "https://gateway.example.com")!, apiKey: "sk-axv-123", model: "claude-x"))
    }

    @Test func modelDefaultsToHaiku() {
        let config = GatewayConfig(info: ["FLGatewayURL": "https://g.example.com", "FLGatewayKey": "k"])
        #expect(config?.model == "claude-haiku-4-5")
    }

    /// CI and fresh clones build without `Config/Secrets.xcconfig`: the key expands
    /// to "" and the app must fall back to on-device behaviour.
    @Test(arguments: [nil, "", "  ", "$(FL_GATEWAY_KEY)"])
    func missingKeyMeansNoConfig(_ key: String?) {
        var info: [String: Any] = ["FLGatewayURL": "https://g.example.com"]
        info["FLGatewayKey"] = key
        #expect(GatewayConfig(info: info) == nil)
    }

    @Test func rejectsNonHTTPSURL() {
        #expect(GatewayConfig(info: ["FLGatewayURL": "http://g.example.com", "FLGatewayKey": "k"]) == nil)
    }
}

@Suite("GatewayClient SSE parsing")
struct GatewayClientParsingTests {
    @Test func textDeltaYieldsText() {
        let line = #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hey"}}"#
        #expect(GatewayClient.step(forLine: line) == .text("Hey"))
    }

    @Test func messageStopEndsTheStream() {
        #expect(GatewayClient.step(forLine: #"data: {"type":"message_stop"}"#) == .stop)
    }

    @Test(arguments: ["event: ping", #"data: {"type":"ping"}"#, #"data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}"#])
    func nonTextFramesAreIgnored(_ line: String) {
        #expect(GatewayClient.step(forLine: line) == .ignore)
    }

    @Test func refusalFails() {
        let line = #"data: {"type":"message_delta","delta":{"stop_reason":"refusal"}}"#
        guard case .fail = GatewayClient.step(forLine: line) else { Issue.record("expected .fail"); return }
    }

    @Test func malformedJSONFails() {
        guard case .fail = GatewayClient.step(forLine: "data: {not json") else { Issue.record("expected .fail"); return }
    }

    @Test func rateLimitStatusesMapToRetryCopy() {
        for status in [402, 429, 529] {
            #expect(
                GatewayClient.httpError(status: status, body: "")
                    == .generationFailed("Too many requests. Please wait a moment and try again."))
        }
    }
}

/// Serves one canned HTTP response per request. Static state, so the suite is serialized.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response: (status: Int, body: String) = (200, "")
    nonisolated(unsafe) static var failure: URLError?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.httpBodyStream.map(Self.read)
        if let failure = Self.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        let http = HTTPURLResponse(
            url: request.url!, statusCode: Self.response.status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.response.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        var data = Data()
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }
}

@Suite("GatewayClient streaming", .serialized)
struct GatewayClientStreamingTests {
    private static let happySSE = """
        event: message_start
        data: {"type":"message_start","message":{"id":"m1"}}

        event: ping
        data: {"type":"ping"}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}

        event: message_stop
        data: {"type":"message_stop"}


        """

    private func makeClient(status: Int = 200, body: String = happySSE, failure: URLError? = nil) -> GatewayClient {
        StubURLProtocol.response = (status, body)
        StubURLProtocol.failure = failure
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return GatewayClient(
            config: GatewayConfig(baseURL: URL(string: "https://gw.example.com")!, apiKey: "sk-axv-test"),
            session: URLSession(configuration: configuration))
    }

    /// Collects every snapshot; the last one is the full text, mirroring `AIService`.
    private func run(_ client: GatewayClient, instructions: String? = "SYS") async
        -> (snapshots: [String], error: Error?)
    {
        var snapshots: [String] = []
        do {
            for try await text in client.stream(instructions: instructions, prompt: "hey") { snapshots.append(text) }
            return (snapshots, nil)
        } catch {
            return (snapshots, error)
        }
    }

    @Test func yieldsAccumulatedSnapshotsNotDeltas() async {
        let result = await run(makeClient())
        #expect(result.snapshots == ["Hello", "Hello world"])
        #expect(result.error == nil)
    }

    @Test func sendsAnthropicShapedRequest() async throws {
        _ = await run(makeClient())
        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://gw.example.com/v1/messages")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-axv-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.timeoutInterval == 60)
        let body = try #require(StubURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "claude-haiku-4-5")
        #expect(json["stream"] as? Bool == true)
        #expect(json["max_tokens"] as? Int == 1024)
        #expect(json["system"] as? String == "SYS")
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [["role": "user", "content": "hey"]])
    }

    /// Summarization has no system prompt; an empty `system` field is rejected by the
    /// API, so it must be omitted rather than sent as "".
    @Test func omitsSystemWhenNil() async throws {
        _ = await run(makeClient(), instructions: nil)
        let body = try #require(StubURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["system"] == nil)
    }

    @Test(arguments: [
        (401, AIServiceError.generationFailed("Gateway auth failed")),
        (403, .generationFailed("Gateway auth failed")),
        (429, .generationFailed("Too many requests. Please wait a moment and try again.")),
        (413, .generationFailed("The conversation is too long. Try clearing some history.")),
        (500, .generationFailed("HTTP 500")),
    ])
    func mapsHTTPStatus(_ status: Int, _ expected: AIServiceError) async {
        let result = await run(makeClient(status: status, body: #"{"type":"error"}"#))
        #expect(result.error as? AIServiceError == expected)
    }

    @Test func mapsTokenLimit400ToContextWindow() async {
        let body =
            #"{"type":"error","error":{"type":"invalid_request_error","message":"prompt is too long: 300000 tokens"}}"#
        let result = await run(makeClient(status: 400, body: body))
        #expect(
            result.error as? AIServiceError
                == .generationFailed("The conversation is too long. Try clearing some history."))
    }

    @Test(arguments: [URLError.Code.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost])
    func mapsConnectivityToOffline(_ code: URLError.Code) async {
        let result = await run(makeClient(failure: URLError(code)))
        #expect(result.error as? AIServiceError == .offline)
    }

    @Test func mapsURLCancelledToCancellation() async {
        let result = await run(makeClient(failure: URLError(.cancelled)))
        #expect(result.error is CancellationError)
    }

    @Test func streamWithoutMessageStopIsInterrupted() async {
        let body = """
            data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}

            """
        let result = await run(makeClient(body: body))
        #expect(result.snapshots == ["Hel"])
        #expect(result.error as? AIServiceError == .generationFailed("Connection interrupted"))
    }

    @Test func inStreamAPIErrorFails() async {
        let body = """
            data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}

            """
        let result = await run(makeClient(body: body))
        #expect(
            result.error as? AIServiceError
                == .generationFailed("Too many requests. Please wait a moment and try again."))
    }

    /// Exercises `continuation.onTermination = { _ in task.cancel() }`: cancelling the
    /// consuming Task mid-stream must tear down the request without hanging.
    @Test func cancellingConsumerTaskStopsStreamWithoutHanging() async {
        let client = makeClient()
        let (signal, signalContinuation) = AsyncStream<Void>.makeStream()
        let task = Task<String, Never> {
            var text = ""
            do {
                for try await snapshot in client.stream(instructions: "SYS", prompt: "hey") {
                    text = snapshot
                    signalContinuation.yield(())
                }
            } catch {}
            return text
        }
        var iterator = signal.makeAsyncIterator()
        _ = await iterator.next()
        task.cancel()
        let text = await task.value  // must not hang
        #expect(!text.isEmpty)
    }
}

@Suite("AIService tier resolution")
struct TierResolutionTests {
    @Test(arguments: [AIAvailability.available, .notEnabled, .notReady])
    func eligibleDevicesStayOnDevice(_ onDevice: AIAvailability) {
        #expect(AIService.resolve(onDevice: onDevice, hasGateway: true, consentGiven: true) == onDevice)
    }

    @Test func ineligibleWithoutBuiltInKeyStaysUnsupported() {
        #expect(AIService.resolve(onDevice: .notEligible, hasGateway: false, consentGiven: true) == .notEligible)
    }

    @Test func ineligibleWithoutConsentAsksForIt() {
        #expect(
            AIService.resolve(onDevice: .notEligible, hasGateway: true, consentGiven: false) == .cloudConsentRequired)
    }

    @Test func ineligibleWithConsentIsAvailable() {
        #expect(AIService.resolve(onDevice: .notEligible, hasGateway: true, consentGiven: true) == .available)
    }
}
