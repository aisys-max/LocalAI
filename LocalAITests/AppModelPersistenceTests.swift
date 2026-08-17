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

    @Test func launchInsertsAndPersistsAFailureMessageForAChatLeftWithATrailingUnansweredUserMessage() async {
        let store = FakePersistenceStore()
        store.chats = [
            "c1": Chat(
                id: "c1", createdAt: Date(timeIntervalSince1970: 0), title: "Chat", snippet: "hi",
                messages: [ChatMessage(id: "m1", role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 1))]
            )
        ]
        store.currentChatId = "c1"

        // Detection runs only after the launch Model-list fetch resolves
        // (it needs to know a Model is available — see detectInterruptedGeneration()).
        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: ["m1"]), persistenceStore: store)
        try? await Task.sleep(nanoseconds: 20_000_000)
        let realMessages = model.chats["c1"]?.messages.filter { !$0.isGreeting } ?? []

        #expect(realMessages.count == 2)
        #expect(realMessages.last?.role == .assistant)
        #expect(store.chats["c1"]?.messages.last?.role == .assistant)
    }

    @Test func launchLeavesAChatAlreadyEndingInAnAssistantMessageUntouched() async {
        let store = FakePersistenceStore()
        store.chats = [
            "c1": Chat(
                id: "c1", createdAt: Date(timeIntervalSince1970: 0), title: "Chat", snippet: "hi",
                messages: [
                    ChatMessage(id: "m1", role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 1)),
                    ChatMessage(id: "m2", role: .assistant, text: "hello", createdAt: Date(timeIntervalSince1970: 2))
                ]
            )
        ]
        store.currentChatId = "c1"
        let saveCountBeforeLaunch = store.saveChatCallCount

        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: ["m1"]), persistenceStore: store)
        try? await Task.sleep(nanoseconds: 20_000_000)
        let realMessages = model.chats["c1"]?.messages.filter { !$0.isGreeting } ?? []

        #expect(realMessages.map(\.id) == ["m1", "m2"])
        #expect(store.saveChatCallCount == saveCountBeforeLaunch)
    }

    @Test func launchDoesNotTouchAChatThatIsNotCurrentlyOpen() async {
        let store = FakePersistenceStore()
        store.chats = [
            "c1": Chat(
                id: "c1", createdAt: Date(timeIntervalSince1970: 0), title: "Open chat", snippet: "hi",
                messages: [ChatMessage(id: "m1", role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 1))]
            ),
            "c2": Chat(
                id: "c2", createdAt: Date(timeIntervalSince1970: 0), title: "Other chat", snippet: "hey",
                messages: [ChatMessage(id: "m2", role: .user, text: "hey", createdAt: Date(timeIntervalSince1970: 1))]
            )
        ]
        store.currentChatId = "c1"

        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: ["m1"]), persistenceStore: store)
        try? await Task.sleep(nanoseconds: 20_000_000)
        let otherChatRealMessages = model.chats["c2"]?.messages.filter { !$0.isGreeting } ?? []

        #expect(otherChatRealMessages.map(\.id) == ["m2"])
    }

    @Test func launchDoesNotMistakeANoModelSelectedSendForAnInterruptedGeneration() async {
        let store = FakePersistenceStore()
        store.chats = [
            "c1": Chat(
                id: "c1", createdAt: Date(timeIntervalSince1970: 0), title: "Chat", snippet: "hi",
                messages: [ChatMessage(id: "m1", role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 1))]
            )
        ]
        store.currentChatId = "c1"

        // No Models available even after the launch fetch resolves — the
        // same on-disk shape sendMessage() leaves when it posts a user
        // Message with no Model selected (see its own "no Model selected
        // yet" comment). Must NOT be mistaken for an interrupted Generation.
        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: []), persistenceStore: store)
        try? await Task.sleep(nanoseconds: 20_000_000)
        let realMessages = model.chats["c1"]?.messages.filter { !$0.isGreeting } ?? []

        #expect(realMessages.map(\.id) == ["m1"])
    }
}
