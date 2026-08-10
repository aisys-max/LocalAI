@testable import LocalAI

struct FakeChatBackendClient: ChatBackendClient {
    var reply: String = "fake reply"
    var chunks: [String]?

    func generateReply(chatId: String, model: String, delayNanoseconds: UInt64) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks ?? [reply] {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}
