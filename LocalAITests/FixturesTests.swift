import Testing
@testable import LocalAI

@Suite struct FixturesTests {
    @Test func seedChatsHaveUniqueIds() {
        let chats = SeedChats.make()
        let ids = Set(chats.map(\.id))
        #expect(ids.count == chats.count)
    }

    @Test func everySeedChatHasAUserAndAssistantMessage() {
        for chat in SeedChats.make() {
            #expect(chat.messages.contains { $0.role == .user })
            #expect(chat.messages.contains { $0.role == .assistant })
        }
    }

    @Test func seedChatsCoverEveryDayGroup() {
        let chats = SeedChats.make()
        for day: ChatDay in [.today, .yesterday, .previous7] {
            #expect(chats.contains { $0.day == day })
        }
    }
}
