import Foundation
import SwiftData

/// SwiftData-backed `PersistenceStore`. Kept separate from the plain
/// `Chat`/`ChatMessage` domain structs (rather than making those `@Model`
/// types directly) so the rest of the app keeps working with simple,
/// value-type structs — this file is the only place that knows about
/// SwiftData.
@Model
final class PersistedChat {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var title: String
    var snippet: String

    init(id: String, createdAt: Date, title: String, snippet: String) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.snippet = snippet
    }
}

@Model
final class PersistedMessage {
    @Attribute(.unique) var id: String
    var chatId: String
    var roleRaw: String
    var text: String
    var model: String?
    var createdAt: Date

    init(id: String, chatId: String, roleRaw: String, text: String, model: String?, createdAt: Date) {
        self.id = id
        self.chatId = chatId
        self.roleRaw = roleRaw
        self.text = text
        self.model = model
        self.createdAt = createdAt
    }
}

/// Singleton row (`id == Self.singletonId`) holding the non-Chat bits of
/// state this ticket persists — `currentChatId`/`draft`. Settings fields
/// join this same row in a later ticket rather than a separate store.
@Model
final class PersistedAppState {
    static let singletonId = "app-state"

    @Attribute(.unique) var id: String
    var currentChatId: String?
    var draft: String

    init(id: String = PersistedAppState.singletonId, currentChatId: String? = nil, draft: String = "") {
        self.id = id
        self.currentChatId = currentChatId
        self.draft = draft
    }
}

final class SwiftDataPersistenceStore: PersistenceStore {
    private let context: ModelContext

    init(container: ModelContainer = SwiftDataPersistenceStore.makeDefaultContainer()) {
        self.context = ModelContext(container)
    }

    private static func makeDefaultContainer() -> ModelContainer {
        let schema = Schema([PersistedChat.self, PersistedMessage.self, PersistedAppState.self])
        let configuration = ModelConfiguration(schema: schema)
        return (try? ModelContainer(for: schema, configurations: [configuration]))
            ?? (try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }

    func loadChats() -> [String: Chat] {
        guard let persistedChats = try? context.fetch(FetchDescriptor<PersistedChat>()) else { return [:] }
        let allMessages = (try? context.fetch(FetchDescriptor<PersistedMessage>())) ?? []
        let messagesByChatId = Dictionary(grouping: allMessages, by: \.chatId)

        var result: [String: Chat] = [:]
        for persistedChat in persistedChats {
            // Ordering by `createdAt` is guaranteed by `AppModel.restoreGreetings()`
            // after load, not here — this store is a dumb read/write boundary.
            // A row with an unparseable `roleRaw` (corruption, a future
            // migration bug) is dropped rather than silently mislabeled as
            // either role.
            let messages = (messagesByChatId[persistedChat.id] ?? [])
                .compactMap { persisted -> ChatMessage? in
                    guard let role = MessageRole(rawValue: persisted.roleRaw) else { return nil }
                    return ChatMessage(
                        id: persisted.id,
                        role: role,
                        text: persisted.text,
                        model: persisted.model,
                        isGreeting: false,
                        createdAt: persisted.createdAt
                    )
                }
            result[persistedChat.id] = Chat(
                id: persistedChat.id,
                createdAt: persistedChat.createdAt,
                title: persistedChat.title,
                snippet: persistedChat.snippet,
                messages: messages
            )
        }
        return result
    }

    func loadCurrentChatId() -> String? {
        fetchAppState()?.currentChatId
    }

    func loadDraft() -> String {
        fetchAppState()?.draft ?? ""
    }

    /// Upserts a single Chat and fully replaces *its own* Messages —
    /// scoped to `chat.id`, not a whole-store rewrite, so saving after one
    /// sent Message costs O(that Chat's Messages), not O(every Message
    /// ever sent across every Chat).
    func saveChat(_ chat: Chat) {
        let chatId = chat.id
        if let existing = fetchChat(id: chatId) {
            existing.createdAt = chat.createdAt
            existing.title = chat.title
            existing.snippet = chat.snippet
        } else {
            context.insert(PersistedChat(id: chatId, createdAt: chat.createdAt, title: chat.title, snippet: chat.snippet))
        }

        fetchMessages(chatId: chatId).forEach { context.delete($0) }
        for message in chat.messages {
            context.insert(PersistedMessage(
                id: message.id,
                chatId: chatId,
                roleRaw: message.role.rawValue,
                text: message.text,
                model: message.model,
                createdAt: message.createdAt
            ))
        }
        try? context.save()
    }

    func deleteChat(id: String) {
        if let existing = fetchChat(id: id) {
            context.delete(existing)
        }
        fetchMessages(chatId: id).forEach { context.delete($0) }
        try? context.save()
    }

    func saveCurrentChatId(_ currentChatId: String?) {
        let state = fetchOrCreateAppState()
        state.currentChatId = currentChatId
        try? context.save()
    }

    func saveDraft(_ draft: String) {
        let state = fetchOrCreateAppState()
        state.draft = draft
        try? context.save()
    }

    private func fetchChat(id: String) -> PersistedChat? {
        let descriptor = FetchDescriptor<PersistedChat>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func fetchMessages(chatId: String) -> [PersistedMessage] {
        let descriptor = FetchDescriptor<PersistedMessage>(predicate: #Predicate { $0.chatId == chatId })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchAppState() -> PersistedAppState? {
        let id = PersistedAppState.singletonId
        let descriptor = FetchDescriptor<PersistedAppState>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func fetchOrCreateAppState() -> PersistedAppState {
        if let existing = fetchAppState() { return existing }
        let created = PersistedAppState()
        context.insert(created)
        return created
    }
}
