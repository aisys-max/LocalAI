import Foundation

/// Talks to a Backend's OpenAI-compatible chat-completions endpoint
/// (`POST /v1/chat/completions`, `stream: true`) — see ADR-0001. Works for any
/// Backend that exposes this surface; the base URL currently defaults to
/// Ollama's local address (ADR scope: Ollama first).
struct OpenAICompatibleChatBackendClient: ChatBackendClient {
    static let defaultBaseURL = URL(string: "http://localhost:11434")!

    let baseURL: URL
    let session: URLSession

    init(baseURL: URL = OpenAICompatibleChatBackendClient.defaultBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func generateReply(chatId: String, model: String, messages: [ChatMessage], delayNanoseconds: UInt64) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(model: model, messages: messages)
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        throw OpenAICompatibleChatBackendClientError.badResponse
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = line.dropFirst("data: ".count)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8) else { continue }
                        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: data)
                        if let content = chunk.choices.first?.delta.content, !content.isEmpty {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeRequest(model: String, messages: [ChatMessage]) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ChatCompletionRequest(
            model: model,
            messages: messages.map {
                ChatCompletionRequest.Message(role: $0.role == .user ? "user" : "assistant", content: $0.text)
            },
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}

enum OpenAICompatibleChatBackendClientError: Error {
    case badResponse
}

struct ChatCompletionRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }
    let model: String
    let messages: [Message]
    let stream: Bool
}

struct ChatCompletionChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }
        let delta: Delta
    }
    let choices: [Choice]
}
