import Foundation

/// The Settings fields persisted alongside Chat data — one unified store,
/// not a separate mechanism (e.g. `UserDefaults`) for Settings.
struct PersistedSettings {
    var backend: Backend
    var model: String?
    var backendServerAddresses: [Backend: String]
    var appearance: AppearanceMode
    var language: AppLanguage

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
    func loadChats() -> [String: Chat]
    func loadCurrentChatId() -> String?
    func loadDraft() -> String
    func loadSettings() -> PersistedSettings

    /// Upserts a single Chat and replaces its Messages — scoped to
    /// `chat.id`, not a whole-store rewrite. The Greeting Message
    /// (`isGreeting == true`), if any, must not be included — callers are
    /// responsible for filtering it out before saving.
    func saveChat(_ chat: Chat)
    func deleteChat(id: String)
    func saveCurrentChatId(_ currentChatId: String?)
    func saveDraft(_ draft: String)
    func saveSettings(_ settings: PersistedSettings)
}
