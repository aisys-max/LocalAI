import Testing
import Foundation
@testable import LocalAI

@MainActor
struct AppModelPersistenceTests {
    @Test func freshEmptyStoreStartsOnOnboarding() {
        let model = makeTestAppModel(persistenceStore: FakePersistenceStore())

        #expect(model.screen == .onboarding)
        #expect(model.chats.isEmpty)
        #expect(model.currentChatId == nil)
    }

    @Test func launchRestoresPersistedChatsCurrentChatIdAndDraft() {
        let store = FakePersistenceStore()
        store.chats = [
            "c1": Chat(
                id: "c1", createdAt: Date(timeIntervalSince1970: 0), title: "Old chat", snippet: "hi",
                messages: [ChatMessage(id: "m1", role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 1))]
            )
        ]
        store.currentChatId = "c1"
        store.draft = "unsent text"

        let model = makeTestAppModel(persistenceStore: store)

        #expect(model.screen == .chat)
        #expect(model.currentChatId == "c1")
        #expect(model.draft == "unsent text")
        #expect(model.chats["c1"]?.messages.contains { $0.text == "hi" && $0.role == .user } == true)
    }

    @Test func launchRestoresAGreetingMessageForEveryLoadedChatWithoutPersistingIt() {
        let store = FakePersistenceStore()
        store.chats = [
            "c1": Chat(id: "c1", createdAt: Date(), title: "Old chat", snippet: "hi", messages: [])
        ]

        let model = makeTestAppModel(persistenceStore: store)

        #expect(model.chats["c1"]?.messages.first?.isGreeting == true)
        // The reconstructed greeting must never itself get written back to the store.
        #expect(store.chats["c1"]?.messages.contains { $0.isGreeting } != true)
    }

    @Test func newChatIsPersistedWithoutItsGreetingMessage() {
        let store = FakePersistenceStore()
        let model = makeTestAppModel(persistenceStore: store)

        model.newChat()
        let chatId = model.currentChatId!

        #expect(store.chats[chatId] != nil)
        #expect(store.chats[chatId]?.messages.isEmpty == true)
        #expect(store.currentChatId == chatId)
    }

    @Test func sendingAMessagePersistsItImmediately() async {
        let store = FakePersistenceStore()
        let model = makeTestAppModel(backendClient: FakeChatBackendClient(reply: "hello there"), persistenceStore: store)
        model.selectModel("test-model")
        model.newChat()
        let chatId = model.currentChatId!

        model.draft = "hi"
        let task = model.sendMessage()

        // Persisted synchronously right after the user Message is appended —
        // before the reply has started streaming back.
        #expect(store.chats[chatId]?.messages.contains { $0.role == .user && $0.text == "hi" } == true)

        await task?.value

        #expect(store.chats[chatId]?.messages.last?.text == "hello there")
    }

    @Test func streamedChunksAreNotPersistedUntilGenerationCompletes() async {
        let store = FakePersistenceStore()
        let model = makeTestAppModel(backendClient: FakeChatBackendClient(chunks: ["hel", "lo ", "there"]), persistenceStore: store)
        model.selectModel("test-model")
        model.newChat()
        let chatId = model.currentChatId!

        model.draft = "hi"
        let saveCountBeforeSend = store.saveChatCallCount
        await model.sendMessage()?.value

        // One save for appending the user Message, one for the completed
        // Generation — not one per streamed chunk.
        #expect(store.saveChatCallCount == saveCountBeforeSend + 2)
        #expect(store.chats[chatId]?.messages.last?.text == "hello there")
    }

    @Test func deletingAMessagePersistsTheRemoval() {
        let store = FakePersistenceStore()
        let model = makeTestAppModel(persistenceStore: store)
        model.newChat()
        let chatId = model.currentChatId!
        model.chats[chatId]?.messages.append(ChatMessage(id: "m1", role: .user, text: "hi"))
        model.persistChat(chatId)

        #expect(store.chats[chatId]?.messages.contains { $0.id == "m1" } == true)

        model.deleteMessage(chatId: chatId, messageId: "m1")

        #expect(store.chats[chatId]?.messages.contains { $0.id == "m1" } == false)
    }

    @Test func deletingChatsPersistsTheRemoval() {
        let store = FakePersistenceStore()
        let model = makeTestAppModel(persistenceStore: store)
        model.newChat()
        let chatId = model.currentChatId!

        model.deleteChats(in: .all)

        #expect(store.chats[chatId] == nil)
    }

    @Test func messageOrderSurvivesASaveLoadRoundTripViaCreatedAt() {
        let store = FakePersistenceStore()
        store.chats = [
            "c1": Chat(
                id: "c1", createdAt: Date(timeIntervalSince1970: 0), title: "Chat", snippet: "",
                messages: [
                    ChatMessage(id: "second", role: .assistant, text: "second", createdAt: Date(timeIntervalSince1970: 20)),
                    ChatMessage(id: "first", role: .user, text: "first", createdAt: Date(timeIntervalSince1970: 10))
                ]
            )
        ]

        let model = makeTestAppModel(persistenceStore: store)
        let realMessages = model.chats["c1"]?.messages.filter { !$0.isGreeting } ?? []

        #expect(realMessages.map(\.id) == ["first", "second"])
    }

    @Test func draftEditsArePersisted() {
        let store = FakePersistenceStore()
        let model = makeTestAppModel(persistenceStore: store)

        model.draft = "half-typed message"

        #expect(store.draft == "half-typed message")
    }
}
