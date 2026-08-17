import Testing
import Foundation
import SwiftData
@testable import LocalAI

@MainActor
struct SwiftDataPersistenceStoreTests {
    private func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema([PersistedChat.self, PersistedMessage.self, PersistedAppState.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    /// The Settings columns on `PersistedAppState` are `Optional` even
    /// though every write always sets them, specifically so SwiftData's
    /// lightweight migration can add them to a store written by the
    /// earlier schema (which only had `currentChatId`/`draft`) without
    /// failing — a non-optional addition fails migration and silently
    /// falls back to an in-memory store, discarding every existing user's
    /// Chats (see `makeDefaultContainer()`'s comment). This test can't
    /// reproduce the migration itself (that needs two schema versions of
    /// the *same* entity, which a single test target can't declare twice),
    /// but it does verify the fallback path a migrated-but-not-yet-written
    /// row would take: nil Settings columns still load as sane defaults.
    @Test func aRowWithNilSettingsColumnsLoadsAsDefaultSettings() {
        let container = makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(PersistedAppState(id: PersistedAppState.singletonId, currentChatId: "c1", draft: "d"))
        // Constructor gives every field a value — explicitly null out the
        // Settings columns to simulate a row migrated from the old schema.
        let inserted = try! context.fetch(FetchDescriptor<PersistedAppState>()).first!
        inserted.backendRaw = nil
        inserted.model = nil
        inserted.backendServerAddressesData = nil
        inserted.appearanceRaw = nil
        inserted.languageRaw = nil
        try! context.save()

        let store = SwiftDataPersistenceStore(container: container)
        let settings = store.loadSettings()

        #expect(store.loadCurrentChatId() == "c1")
        #expect(store.loadDraft() == "d")
        #expect(settings.backend == .ollama)
        #expect(settings.model == nil)
        #expect(settings.backendServerAddresses.isEmpty)
        #expect(settings.appearance == .system)
        #expect(settings.language == .en)
    }

    @Test func loadChatsOnAnEmptyStoreReturnsEmpty() {
        let store = SwiftDataPersistenceStore(container: makeInMemoryContainer())
        #expect(store.loadChats().isEmpty)
    }

    @Test func saveChatThenLoadChatsRoundTripsChatAndMessages() {
        let store = SwiftDataPersistenceStore(container: makeInMemoryContainer())
        let chat = Chat(
            id: "c1", createdAt: Date(timeIntervalSince1970: 0), title: "Title", snippet: "snip",
            messages: [
                ChatMessage(id: "m1", role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 1)),
                ChatMessage(id: "m2", role: .assistant, text: "hello", model: "test-model", createdAt: Date(timeIntervalSince1970: 2))
            ]
        )

        store.saveChat(chat)
        let loaded = store.loadChats()["c1"]

        #expect(loaded?.title == "Title")
        #expect(loaded?.snippet == "snip")
        #expect(Set(loaded?.messages.map(\.id) ?? []) == ["m1", "m2"])
        #expect(loaded?.messages.first { $0.id == "m2" }?.model == "test-model")
        #expect(loaded?.messages.first { $0.id == "m2" }?.role == .assistant)
    }

    @Test func savingAChatTwiceReplacesItsMessagesRatherThanAccumulating() {
        let store = SwiftDataPersistenceStore(container: makeInMemoryContainer())
        var chat = Chat(id: "c1", createdAt: Date(), title: "t", snippet: "s", messages: [
            ChatMessage(id: "m1", role: .user, text: "one")
        ])
        store.saveChat(chat)

        chat.messages = [
            ChatMessage(id: "m1", role: .user, text: "one"),
            ChatMessage(id: "m2", role: .assistant, text: "two")
        ]
        store.saveChat(chat)

        let loaded = store.loadChats()["c1"]
        #expect(loaded?.messages.count == 2)
    }

    @Test func savingOneChatDoesNotTouchAnotherChatsMessages() {
        let store = SwiftDataPersistenceStore(container: makeInMemoryContainer())
        store.saveChat(Chat(id: "c1", createdAt: Date(), title: "t1", snippet: "s1", messages: [ChatMessage(id: "m1", role: .user, text: "one")]))
        store.saveChat(Chat(id: "c2", createdAt: Date(), title: "t2", snippet: "s2", messages: [ChatMessage(id: "m2", role: .user, text: "two")]))

        // Re-saving c1 (with an updated title) must leave c2 untouched —
        // saveChat is scoped to the one Chat, not a whole-store rewrite.
        store.saveChat(Chat(id: "c1", createdAt: Date(), title: "t1 updated", snippet: "s1", messages: [ChatMessage(id: "m1", role: .user, text: "one")]))

        let chats = store.loadChats()
        #expect(chats["c1"]?.title == "t1 updated")
        #expect(chats["c2"]?.messages.map(\.id) == ["m2"])
    }

    @Test func deleteChatRemovesTheChatAndItsMessages() {
        let store = SwiftDataPersistenceStore(container: makeInMemoryContainer())
        store.saveChat(Chat(id: "c1", createdAt: Date(), title: "t", snippet: "s", messages: [ChatMessage(id: "m1", role: .user, text: "one")]))

        store.deleteChat(id: "c1")

        #expect(store.loadChats()["c1"] == nil)
    }

    @Test func deletingAnUnknownChatIdIsANoOp() {
        let store = SwiftDataPersistenceStore(container: makeInMemoryContainer())
        store.deleteChat(id: "does-not-exist")
        #expect(store.loadChats().isEmpty)
    }

    @Test func currentChatIdAndDraftRoundTripThroughTheSingletonRow() {
        let store = SwiftDataPersistenceStore(container: makeInMemoryContainer())
        #expect(store.loadCurrentChatId() == nil)
        #expect(store.loadDraft() == "")

        store.saveCurrentChatId("c1")
        store.saveDraft("unsent")

        #expect(store.loadCurrentChatId() == "c1")
        #expect(store.loadDraft() == "unsent")
    }

    @Test func savingCurrentChatIdAndDraftRepeatedlyUpdatesTheSameRowRatherThanAccumulating() {
        let store = SwiftDataPersistenceStore(container: makeInMemoryContainer())
        store.saveCurrentChatId("c1")
        store.saveCurrentChatId("c2")
        store.saveDraft("first")
        store.saveDraft("second")

        #expect(store.loadCurrentChatId() == "c2")
        #expect(store.loadDraft() == "second")
    }

    @Test func aMessageWithAnUnparseableRoleIsDroppedRatherThanMisclassified() {
        let container = makeInMemoryContainer()
        let store = SwiftDataPersistenceStore(container: container)
        store.saveChat(Chat(id: "c1", createdAt: Date(), title: "t", snippet: "s", messages: [
            ChatMessage(id: "m1", role: .user, text: "kept")
        ]))

        // Simulate corrupted/unrecognized role data landing directly in the store.
        let context = ModelContext(container)
        context.insert(PersistedMessage(id: "m2", chatId: "c1", roleRaw: "not-a-real-role", text: "corrupt", model: nil, createdAt: Date()))
        try? context.save()

        let messages = store.loadChats()["c1"]?.messages ?? []
        #expect(messages.map(\.id) == ["m1"])
    }

    @Test func loadSettingsOnAnEmptyStoreReturnsTheDefault() {
        let store = SwiftDataPersistenceStore(container: makeInMemoryContainer())
        let settings = store.loadSettings()

        #expect(settings.backend == .ollama)
        #expect(settings.model == nil)
        #expect(settings.backendServerAddresses.isEmpty)
        #expect(settings.appearance == .system)
        #expect(settings.language == .en)
    }

    @Test func saveSettingsThenLoadSettingsRoundTripsEveryField() {
        let store = SwiftDataPersistenceStore(container: makeInMemoryContainer())
        let settings = PersistedSettings(
            backend: .lmstudio,
            model: "some-model",
            backendServerAddresses: [.ollama: "http://a:1", .lmstudio: "http://b:2"],
            appearance: .dark,
            language: .ko
        )

        store.saveSettings(settings)
        let loaded = store.loadSettings()

        #expect(loaded.backend == .lmstudio)
        #expect(loaded.model == "some-model")
        #expect(loaded.backendServerAddresses == [.ollama: "http://a:1", .lmstudio: "http://b:2"])
        #expect(loaded.appearance == .dark)
        #expect(loaded.language == .ko)
    }

    @Test func savingSettingsRepeatedlyUpdatesTheSameRowRatherThanAccumulating() {
        let store = SwiftDataPersistenceStore(container: makeInMemoryContainer())
        store.saveSettings(PersistedSettings(backend: .ollama, model: "m1", backendServerAddresses: [:], appearance: .light, language: .en))
        store.saveSettings(PersistedSettings(backend: .lmstudio, model: "m2", backendServerAddresses: [:], appearance: .dark, language: .ko))

        let loaded = store.loadSettings()
        #expect(loaded.backend == .lmstudio)
        #expect(loaded.model == "m2")
        #expect(loaded.appearance == .dark)
        #expect(loaded.language == .ko)
    }

    @Test func settingsAndAppStateShareTheSameSingletonRowWithoutClobberingEachOther() {
        let store = SwiftDataPersistenceStore(container: makeInMemoryContainer())
        store.saveCurrentChatId("c1")
        store.saveDraft("unsent")
        store.saveSettings(PersistedSettings(backend: .lmstudio, model: "m1", backendServerAddresses: [:], appearance: .dark, language: .ko))

        #expect(store.loadCurrentChatId() == "c1")
        #expect(store.loadDraft() == "unsent")
        #expect(store.loadSettings().backend == .lmstudio)
    }
}
