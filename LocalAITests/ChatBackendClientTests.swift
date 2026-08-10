import Testing
@testable import LocalAI

@Suite struct ChatBackendClientTests {
    @Test func generateReplyReturnsACannedReply() async {
        let client = SimulatedChatBackendClient()
        let reply = await client.generateReply(chatId: "c1", model: "Llama 3.1 8B", delayNanoseconds: 0)
        #expect(CannedReplies.all.contains(reply))
    }

    @Test func generateReplyIsNeverEmptyAcrossRepeatedCalls() async {
        let client = SimulatedChatBackendClient()
        for _ in 0..<20 {
            let reply = await client.generateReply(chatId: "c1", model: "Llama 3.1 8B", delayNanoseconds: 0)
            #expect(!reply.isEmpty)
        }
    }
}
