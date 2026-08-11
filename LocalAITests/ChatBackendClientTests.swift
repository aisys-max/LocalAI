import Testing
@testable import LocalAI

@Suite struct ChatBackendClientTests {
    @Test func generateReplyStreamsASingleCannedReplyChunk() async throws {
        let client = SimulatedChatBackendClient()
        var chunks: [String] = []
        for try await chunk in client.generateReply(chatId: "c1", model: "Llama 3.1 8B", messages: [], delayNanoseconds: 0) {
            chunks.append(chunk)
        }
        #expect(chunks.count == 1)
        #expect(CannedReplies.all.contains(chunks[0]))
    }

    @Test func generateReplyIsNeverEmptyAcrossRepeatedCalls() async throws {
        let client = SimulatedChatBackendClient()
        for _ in 0..<20 {
            var reply = ""
            for try await chunk in client.generateReply(chatId: "c1", model: "Llama 3.1 8B", messages: [], delayNanoseconds: 0) {
                reply += chunk
            }
            #expect(!reply.isEmpty)
        }
    }
}
