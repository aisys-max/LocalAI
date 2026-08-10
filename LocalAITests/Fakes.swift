@testable import LocalAI

struct FakeChatBackendClient: ChatBackendClient {
    var reply: String = "fake reply"

    func generateReply(chatId: String, model: String, delayNanoseconds: UInt64) async -> String {
        reply
    }
}
