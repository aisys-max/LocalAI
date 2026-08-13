import Testing
import Foundation
@testable import LocalAI

struct OpenAICompatibleChatBackendClientTests {
    private let testBaseURL = URL(string: "http://localhost:11434")!

    @Test func requestHitsChatCompletionsEndpointWithModelAndMessages() async throws {
        StubURLProtocol.stub(status: 200, body: sseBody(["hi"]))
        let client = OpenAICompatibleChatBackendClient(session: stubbedSession())

        let messages = [
            ChatMessage(id: "1", role: .assistant, text: "hello!"),
            ChatMessage(id: "2", role: .user, text: "what's up"),
        ]
        for try await _ in client.generateReply(chatId: "c1", model: "llama3", messages: messages, baseURL: testBaseURL, delayNanoseconds: 0) {}

        let request = try #require(StubURLProtocol.capturedRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "http://localhost:11434/v1/chat/completions")

        let body = try #require(request.bodyData)
        let decoded = try JSONDecoder().decode(ChatCompletionRequest.self, from: body)
        #expect(decoded.model == "llama3")
        #expect(decoded.stream == true)
        #expect(decoded.messages.map(\.role) == ["assistant", "user"])
        #expect(decoded.messages.map(\.content) == ["hello!", "what's up"])
    }

    @Test func requestHitsTheConfiguredBaseURLNotAHardcodedOne() async throws {
        StubURLProtocol.stub(status: 200, body: sseBody(["hi"]))
        let client = OpenAICompatibleChatBackendClient(session: stubbedSession())
        let customURL = URL(string: "http://192.168.1.5:1234")!

        for try await _ in client.generateReply(chatId: "c1", model: "llama3", messages: [], baseURL: customURL, delayNanoseconds: 0) {}

        let request = try #require(StubURLProtocol.capturedRequest)
        #expect(request.url?.absoluteString == "http://192.168.1.5:1234/v1/chat/completions")
    }

    @Test func streamedReplyYieldsEachDeltaChunkInOrder() async throws {
        StubURLProtocol.stub(status: 200, body: sseBody(["Hel", "lo ", "there"]))
        let client = OpenAICompatibleChatBackendClient(session: stubbedSession())

        var chunks: [String] = []
        for try await chunk in client.generateReply(chatId: "c1", model: "llama3", messages: [], baseURL: testBaseURL, delayNanoseconds: 0) {
            chunks.append(chunk)
        }

        #expect(chunks == ["Hel", "lo ", "there"])
    }

    @Test func nonSuccessResponseThrows() async throws {
        StubURLProtocol.stub(status: 500, body: Data())
        let client = OpenAICompatibleChatBackendClient(session: stubbedSession())

        await #expect(throws: Error.self) {
            for try await _ in client.generateReply(chatId: "c1", model: "llama3", messages: [], baseURL: testBaseURL, delayNanoseconds: 0) {}
        }
    }

    private func stubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func sseBody(_ chunks: [String]) -> Data {
        var lines: [String] = []
        for chunk in chunks {
            let json = "{\"choices\":[{\"delta\":{\"content\":\"\(chunk)\"}}]}"
            lines.append("data: \(json)")
        }
        lines.append("data: [DONE]")
        return lines.joined(separator: "\n\n").data(using: .utf8)!
    }
}

private extension URLRequest {
    /// `httpBody` is nil on requests captured via `URLProtocol` (it's moved into
    /// `httpBodyStream`), so read the body back out through the stream instead.
    var bodyData: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

/// Intercepts requests made through a `URLSession` configured with this
/// protocol class, returning a canned status/body and recording the last
/// request made — the seam used to test `OpenAICompatibleChatBackendClient`
/// without a live server.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var _status = 200
    private static var _body = Data()
    private static var _capturedRequest: URLRequest?

    static var capturedRequest: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return _capturedRequest
    }

    static func stub(status: Int, body: Data) {
        lock.lock()
        _status = status
        _body = body
        _capturedRequest = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._capturedRequest = request
        let status = Self._status
        let body = Self._body
        Self.lock.unlock()

        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
