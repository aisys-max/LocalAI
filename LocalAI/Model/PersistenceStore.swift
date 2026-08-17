import Foundation

/// Persists Chat/conversation state across app relaunches. A dumb read/write
/// boundary — `AppModel` decides *when* to load/save (once at launch, after
/// relevant mutations); the store just moves data. Mirrors the
/// `ChatBackendClient`/`ModelCatalogClient` injection pattern so `AppModel`
/// stays unit-testable without a real SwiftData store.
protocol PersistenceStore {
    func loadChats() -> [String: Chat]
    func loadCurrentChatId() -> String?
    func loadDraft() -> String

    /// Upserts a single Chat and replaces its Messages — scoped to
    /// `chat.id`, not a whole-store rewrite. The Greeting Message
    /// (`isGreeting == true`), if any, must not be included — callers are
    /// responsible for filtering it out before saving.
    func saveChat(_ chat: Chat)
    func deleteChat(id: String)
    func saveCurrentChatId(_ currentChatId: String?)
    func saveDraft(_ draft: String)
}
