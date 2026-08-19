import Foundation
import SwiftData
import os

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
    // Optional (not a plain Bool), same reasoning as PersistedAppState's
    // Settings columns below: this attribute was added after Greetings
    // stripped themselves before ever reaching this store, so existing
    // installs may have message rows written by the earlier schema. A
    // non-optional addition fails SwiftData's lightweight migration; a nil
    // value here (an old row, or a genuinely-absent flag) reads as `false`.
    var isGreeting: Bool?
    /// The Backend a Greeting was worded against (`ChatMessage.backend`),
    /// nil for every non-Greeting Message. Stored raw (`Backend.rawValue`)
    /// rather than as a relationship, matching `model`'s plain-`String?`
    /// shape above.
    var backendRaw: String?

    init(id: String, chatId: String, roleRaw: String, text: String, model: String?, createdAt: Date, isGreeting: Bool, backendRaw: String?) {
        self.id = id
        self.chatId = chatId
        self.roleRaw = roleRaw
        self.text = text
        self.model = model
        self.createdAt = createdAt
        self.isGreeting = isGreeting
        self.backendRaw = backendRaw
    }
}

/// Singleton row (`id == Self.singletonId`) holding every non-Chat bit of
/// state this app persists — `currentChatId`/`draft` plus all of Settings —
/// one unified store rather than a separate mechanism (e.g. `UserDefaults`)
/// for Settings. `backendServerAddressesData` is `[Backend: String]`
/// JSON-encoded keyed by `Backend.rawValue` — SwiftData attributes don't
/// support `Dictionary` directly at this deployment target (iOS 17).
///
/// The Settings fields are `Optional` even though every write always sets
/// them: SwiftData's automatic lightweight migration can only add a new
/// attribute to a store written by an earlier schema (this app shipped
/// once already with only `currentChatId`/`draft` on this row) when that
/// attribute is Optional — a non-optional addition fails migration and
/// `makeDefaultContainer()` falls back to an in-memory store, silently
/// discarding every existing user's Chats. `loadSettings()` treats a nil
/// value (an old row that predates these columns) the same as "use the
/// default," same as a brand-new row.
@Model
final class PersistedAppState {
    static let singletonId = "app-state"

    @Attribute(.unique) var id: String
    var currentChatId: String?
    var draft: String
    var backendRaw: String?
    var model: String?
    var backendServerAddressesData: Data?
    var appearanceRaw: String?
    var languageRaw: String?
    var retentionPeriodRaw: String?

    init(
        id: String = PersistedAppState.singletonId,
        currentChatId: String? = nil,
        draft: String = "",
        backendRaw: String = Backend.ollama.rawValue,
        model: String? = nil,
        backendServerAddressesData: Data = Data(),
        appearanceRaw: String = AppearanceMode.system.rawValue,
        languageRaw: String = AppLanguage.en.rawValue,
        retentionPeriodRaw: String = RetentionPeriod.oneMonth.rawValue
    ) {
        self.id = id
        self.currentChatId = currentChatId
        self.draft = draft
        self.backendRaw = backendRaw
        self.model = model
        self.backendServerAddressesData = backendServerAddressesData
        self.appearanceRaw = appearanceRaw
        self.languageRaw = languageRaw
        self.retentionPeriodRaw = retentionPeriodRaw
    }
}

/// First on-disk schema version. Every future schema change (a new
/// non-optional column, a renamed/removed field, a new model) should add a
/// `LocalAISchemaV2` etc. plus a corresponding `MigrationStage` to
/// `LocalAIMigrationPlan.stages` below, rather than relying on SwiftData's
/// automatic lightweight migration — lightweight migration only covers
/// adding new `Optional` attributes (see the Settings-columns comment on
/// `PersistedAppState` for a case that already required working around
/// this limit), and silently falls back to an in-memory store on anything
/// it can't handle, discarding every existing user's Chats.
enum LocalAISchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [PersistedChat.self, PersistedMessage.self, PersistedAppState.self] }
}

enum LocalAIMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LocalAISchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

@MainActor
final class SwiftDataPersistenceStore: PersistenceStore {
    private let context: ModelContext
    private static let logger = Logger(subsystem: "com.local.localai", category: "persistence")

    // Same default-argument-isolation issue as `AppModel.init` — a default
    // parameter value can't call this (now-MainActor) type's own static
    // method, so the default resolves inside the init body instead.
    init(container: ModelContainer? = nil) {
        self.context = ModelContext(container ?? Self.makeDefaultContainer())
    }

    /// Falls back to an in-memory store (discarding every existing user's
    /// Chats) if opening/migrating the on-disk store fails — logged here
    /// specifically, since this is the one failure in this file severe
    /// enough that it's worth knowing about even without a debugger
    /// attached (every other failure in this file only loses one write,
    /// not the whole store).
    private static func makeDefaultContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: LocalAISchemaV1.self)
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, migrationPlan: LocalAIMigrationPlan.self, configurations: configuration)
        } catch {
            logger.error("Failed to open/migrate on-disk store, falling back to in-memory: \(error, privacy: .public)")
            return try! ModelContainer(for: schema, migrationPlan: LocalAIMigrationPlan.self, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        }
    }

    /// Every write path funnels through here rather than calling
    /// `context.save()` directly, so a save failure (disk full, store
    /// corruption) is at least logged instead of silently discarded — the
    /// in-memory `AppModel` state already changed by the time this runs,
    /// so there's no user-facing recovery to attempt here, only visibility.
    private func saveContext() {
        do {
            try context.save()
        } catch {
            Self.logger.error("Failed to save ModelContext: \(error, privacy: .public)")
        }
    }

    func loadChats() -> [String: Chat] {
        guard let persistedChats = try? context.fetch(FetchDescriptor<PersistedChat>()) else { return [:] }
        // Sorted by `createdAt` here, not left to a caller — a fetch with no
        // `sortBy` isn't guaranteed to come back in insertion/chronological
        // order, and unlike the old design (which used to unconditionally
        // re-sort every Chat's Messages after load), nothing downstream can
        // be relied on to fix that up for a Chat that already has a
        // persisted Greeting (see `AppModel.bootstrapMissingGreetings()`,
        // which only touches Chats with none).
        var messagesDescriptor = FetchDescriptor<PersistedMessage>()
        messagesDescriptor.sortBy = [SortDescriptor(\.createdAt)]
        let allMessages = (try? context.fetch(messagesDescriptor)) ?? []
        let messagesByChatId = Dictionary(grouping: allMessages, by: \.chatId)

        var result: [String: Chat] = [:]
        for persistedChat in persistedChats {
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
                        backend: persisted.backendRaw.flatMap(Backend.init(rawValue:)),
                        isGreeting: persisted.isGreeting ?? false,
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

    func loadSettings() -> PersistedSettings {
        guard let state = fetchAppState() else { return .default }
        let addressesData = state.backendServerAddressesData ?? Data()
        let addresses = (try? JSONDecoder().decode([String: String].self, from: addressesData)) ?? [:]
        var backendServerAddresses: [Backend: String] = [:]
        for (rawBackend, address) in addresses {
            if let backend = Backend(rawValue: rawBackend) {
                backendServerAddresses[backend] = address
            }
        }
        return PersistedSettings(
            backend: state.backendRaw.flatMap(Backend.init(rawValue:)) ?? .ollama,
            model: state.model,
            backendServerAddresses: backendServerAddresses,
            appearance: state.appearanceRaw.flatMap(AppearanceMode.init(rawValue:)) ?? .system,
            language: state.languageRaw.flatMap(AppLanguage.init(rawValue:)) ?? .en,
            retentionPeriod: state.retentionPeriodRaw.flatMap(RetentionPeriod.init(rawValue:)) ?? .oneMonth
        )
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
                createdAt: message.createdAt,
                isGreeting: message.isGreeting,
                backendRaw: message.backend?.rawValue
            ))
        }
        saveContext()
    }

    func deleteChat(id: String) {
        if let existing = fetchChat(id: id) {
            context.delete(existing)
        }
        fetchMessages(chatId: id).forEach { context.delete($0) }
        saveContext()
    }

    func saveCurrentChatId(_ currentChatId: String?) {
        let state = fetchOrCreateAppState()
        state.currentChatId = currentChatId
        saveContext()
    }

    func saveDraft(_ draft: String) {
        let state = fetchOrCreateAppState()
        state.draft = draft
        saveContext()
    }

    func saveSettings(_ settings: PersistedSettings) {
        let state = fetchOrCreateAppState()
        state.backendRaw = settings.backend.rawValue
        state.model = settings.model
        let addresses = Dictionary(uniqueKeysWithValues: settings.backendServerAddresses.map { ($0.key.rawValue, $0.value) })
        state.backendServerAddressesData = (try? JSONEncoder().encode(addresses)) ?? Data()
        state.appearanceRaw = settings.appearance.rawValue
        state.languageRaw = settings.language.rawValue
        state.retentionPeriodRaw = settings.retentionPeriod.rawValue
        saveContext()
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
