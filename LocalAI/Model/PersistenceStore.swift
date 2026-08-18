import Foundation

/// The Settings fields persisted alongside Chat data — one unified store,
/// not a separate mechanism (e.g. `UserDefaults`) for Settings.
struct PersistedSettings {
    var backend: Backend
    var model: String?
    var backendServerAddresses: [Backend: String]
    var appearance: AppearanceMode
    var language: AppLanguage
    // Inline default (unlike its sibling fields above, which rely solely
    // on `.default` below) so existing `PersistedSettings(...)` call sites
    // written before this field existed keep compiling without every one
    // needing an explicit `retentionPeriod:` argument.
    var retentionPeriod: RetentionPeriod = .oneMonth

    static let `default` = PersistedSettings(
        backend: .ollama, model: nil, backendServerAddresses: [:], appearance: .system, language: .en
    )
}

/// Persists Chat/conversation state and Settings across app relaunches. A
/// dumb read/write boundary — `AppModel` decides *when* to load/save (once
/// at launch, after relevant mutations); the store just moves data. Mirrors
/// the `ChatBackendClient`/`ModelCatalogClient` injection pattern so
/// `AppModel` stays unit-testable without a real SwiftData store.
protocol PersistenceStore {
    /// Each Chat's Messages come back ordered by `createdAt` — callers rely
    /// on this rather than re-sorting themselves (see
    /// `AppModel.bootstrapMissingGreetings()`, which only re-derives order
    /// for a legacy Chat that predates persisted Greetings; every other Chat
    /// depends on this guarantee holding here).
    func loadChats() -> [String: Chat]
    func loadCurrentChatId() -> String?
    func loadDraft() -> String
    func loadSettings() -> PersistedSettings

    /// Upserts a single Chat and replaces its Messages — scoped to
    /// `chat.id`, not a whole-store rewrite. Greeting Messages
    /// (`isGreeting == true`) are regular Messages here, saved like any
    /// other — they're no longer stripped before this is called.
    func saveChat(_ chat: Chat)
    func deleteChat(id: String)
    func saveCurrentChatId(_ currentChatId: String?)
    func saveDraft(_ draft: String)
    func saveSettings(_ settings: PersistedSettings)
}
