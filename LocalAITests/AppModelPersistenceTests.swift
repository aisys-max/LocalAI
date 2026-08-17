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
                // Recent, not epoch-0 — this Chat must survive the
                // default (1-month) Retention Period pruning at launch.
                id: "c1", createdAt: Date(), title: "Old chat", snippet: "hi",
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
                // Recent, not epoch-0 — this Chat must survive the
                // default (1-month) Retention Period pruning at launch.
                id: "c1", createdAt: Date(), title: "Chat", snippet: "",
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

    @Test func launchRestoresPersistedSettings() {
        let store = FakePersistenceStore()
        store.settings = PersistedSettings(
            backend: .lmstudio, model: "restored-model",
            backendServerAddresses: [.lmstudio: "http://custom:1234"],
            appearance: .dark, language: .ko
        )

        let model = makeTestAppModel(persistenceStore: store)

        #expect(model.backend == .lmstudio)
        #expect(model.model == "restored-model")
        #expect(model.backendServerAddresses[.lmstudio] == "http://custom:1234")
        #expect(model.appearance == .dark)
        #expect(model.language == .ko)
    }

    @Test func settingsChangesArePersistedImmediately() {
        let store = FakePersistenceStore()
        let model = makeTestAppModel(persistenceStore: store)

        model.setAppearance(.dark)
        model.setLanguage(.ko)
        model.setServerAddress("http://custom:9999", for: .ollama)
        model.selectModel("picked-model")

        #expect(store.settings.appearance == .dark)
        #expect(store.settings.language == .ko)
        #expect(store.settings.backendServerAddresses[.ollama] == "http://custom:9999")
        #expect(store.settings.model == "picked-model")
    }

    @Test func aPersistedModelNoLongerInTheFetchedListIsClearedAndThePersistedCorrectionSaved() async {
        let store = FakePersistenceStore()
        store.settings = PersistedSettings(backend: .ollama, model: "uninstalled-model", backendServerAddresses: [:], appearance: .system, language: .en)

        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: ["m1", "m2"]), persistenceStore: store)
        #expect(model.model == "uninstalled-model")

        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(model.model == nil)
        #expect(store.settings.model == nil)
    }

    @Test func aPersistedModelStillInTheFetchedListIsLeftAlone() async {
        let store = FakePersistenceStore()
        store.settings = PersistedSettings(backend: .ollama, model: "m2", backendServerAddresses: [:], appearance: .system, language: .en)

        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: ["m1", "m2"]), persistenceStore: store)

        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(model.model == "m2")
    }

    private func makeAgedChat(id: String, daysAgo: Int, now: Date) -> Chat {
        let createdAt = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        return Chat(id: id, createdAt: createdAt, title: id, snippet: id, messages: [
            ChatMessage(id: id + "-m1", role: .user, text: id, createdAt: createdAt)
        ])
    }

    @Test func launchPrunesChatsOlderThanAOneWeekRetentionPeriod() {
        let now = Date()
        let store = FakePersistenceStore()
        store.chats = [
            "recent": makeAgedChat(id: "recent", daysAgo: 2, now: now),
            "old": makeAgedChat(id: "old", daysAgo: 10, now: now)
        ]
        store.settings = PersistedSettings(backend: .ollama, model: nil, backendServerAddresses: [:], appearance: .system, language: .en, retentionPeriod: .oneWeek)

        let model = makeTestAppModel(persistenceStore: store)

        #expect(model.chats["recent"] != nil)
        #expect(model.chats["old"] == nil)
        #expect(store.chats["old"] == nil)
    }

    @Test func launchPrunesChatsOlderThanAOneMonthRetentionPeriod() {
        let now = Date()
        let store = FakePersistenceStore()
        store.chats = [
            "recent": makeAgedChat(id: "recent", daysAgo: 10, now: now),
            "old": makeAgedChat(id: "old", daysAgo: 40, now: now)
        ]
        store.settings = PersistedSettings(backend: .ollama, model: nil, backendServerAddresses: [:], appearance: .system, language: .en, retentionPeriod: .oneMonth)

        let model = makeTestAppModel(persistenceStore: store)

        #expect(model.chats["recent"] != nil)
        #expect(model.chats["old"] == nil)
    }

    @Test func launchPrunesChatsOlderThanASixMonthRetentionPeriod() {
        let now = Date()
        let store = FakePersistenceStore()
        store.chats = [
            "recent": makeAgedChat(id: "recent", daysAgo: 60, now: now),
            "old": makeAgedChat(id: "old", daysAgo: 200, now: now)
        ]
        store.settings = PersistedSettings(backend: .ollama, model: nil, backendServerAddresses: [:], appearance: .system, language: .en, retentionPeriod: .sixMonths)

        let model = makeTestAppModel(persistenceStore: store)

        #expect(model.chats["recent"] != nil)
        #expect(model.chats["old"] == nil)
    }

    @Test func launchPruningClearsCurrentChatIdWhenTheOpenChatIsPruned() {
        let now = Date()
        let store = FakePersistenceStore()
        store.chats = ["old": makeAgedChat(id: "old", daysAgo: 40, now: now)]
        store.currentChatId = "old"
        store.settings = PersistedSettings(backend: .ollama, model: nil, backendServerAddresses: [:], appearance: .system, language: .en, retentionPeriod: .oneMonth)

        let model = makeTestAppModel(persistenceStore: store)

        #expect(model.currentChatId == nil)
        #expect(model.screen == .onboarding)
    }

    @Test func launchPruningTheOpenChatWithOthersSurvivingStartsAFreshChatInstead() {
        let now = Date()
        let store = FakePersistenceStore()
        store.chats = [
            "old": makeAgedChat(id: "old", daysAgo: 40, now: now),
            "recent": makeAgedChat(id: "recent", daysAgo: 1, now: now)
        ]
        store.currentChatId = "old"
        store.settings = PersistedSettings(backend: .ollama, model: nil, backendServerAddresses: [:], appearance: .system, language: .en, retentionPeriod: .oneMonth)

        let model = makeTestAppModel(persistenceStore: store)

        // The pruned Chat's id must not linger as current, and — since a
        // surviving Chat exists but there's no chat-switcher UI to reach it
        // — a fresh Chat is started rather than leaving `screen == .chat`
        // pointing at nothing.
        #expect(model.currentChatId != nil)
        #expect(model.currentChatId != "old")
        #expect(model.screen == .chat)
        #expect(model.chats["recent"] != nil)
    }

    @Test func shorteningRetentionPeriodPrunesImmediatelyWithoutRelaunch() {
        let now = Date()
        let store = FakePersistenceStore()
        store.chats = ["old": makeAgedChat(id: "old", daysAgo: 10, now: now)]
        store.settings = PersistedSettings(backend: .ollama, model: nil, backendServerAddresses: [:], appearance: .system, language: .en, retentionPeriod: .oneMonth)

        let model = makeTestAppModel(persistenceStore: store)
        #expect(model.chats["old"] != nil)

        model.setRetentionPeriod(.oneWeek)

        #expect(model.chats["old"] == nil)
        #expect(store.chats["old"] == nil)
        #expect(store.settings.retentionPeriod == .oneWeek)
    }

    @Test func lengtheningRetentionPeriodDoesNotResurrectAlreadyPrunedChats() {
        let now = Date()
        let store = FakePersistenceStore()
        // Already pruned at launch (older than a week) before the test
        // even changes the setting.
        store.chats = ["old": makeAgedChat(id: "old", daysAgo: 10, now: now)]
        store.settings = PersistedSettings(backend: .ollama, model: nil, backendServerAddresses: [:], appearance: .system, language: .en, retentionPeriod: .oneWeek)

        let model = makeTestAppModel(persistenceStore: store)
        #expect(model.chats["old"] == nil)

        model.setRetentionPeriod(.sixMonths)

        #expect(model.chats["old"] == nil)
    }

    @Test func manualBulkDeleteIsUnaffectedByRetentionPeriod() {
        let now = Date()
        let store = FakePersistenceStore()
        store.settings = PersistedSettings(backend: .ollama, model: nil, backendServerAddresses: [:], appearance: .system, language: .en, retentionPeriod: .sixMonths)
        let model = makeTestAppModel(persistenceStore: store)
        model.chats["c1"] = makeAgedChat(id: "c1", daysAgo: 0, now: now)

        model.deleteChats(in: .today, now: now)

        #expect(model.chats["c1"] == nil)
    }
}
