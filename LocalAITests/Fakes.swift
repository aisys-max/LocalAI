import Foundation
@testable import LocalAI

struct FakeChatBackendClient: ChatBackendClient {
    var reply: String = "fake reply"
    var chunks: [String]?
    /// When set, the stream yields any given `chunks` (simulating a
    /// partway failure) or none at all (an up-front failure), then fails.
    var error: Error?

    func generateReply(chatId: String, model: String, messages: [ChatMessage], baseURL: URL, delayNanoseconds: UInt64) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks ?? (error == nil ? [reply] : []) {
                continuation.yield(chunk)
            }
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }
}

enum FakeModelCatalogClientError: Error {
    case failed
}

struct FakeModelCatalogClient: ModelCatalogClient {
    var models: [String] = ["fake-model-1", "fake-model-2"]
    var shouldFail = false

    func fetchModels(baseURL: URL) async throws -> [String] {
        if shouldFail { throw FakeModelCatalogClientError.failed }
        return models
    }
}

/// A reference-type `ModelCatalogClient` fake, for tests that need to change
/// what the *same* injected instance returns between calls (e.g. retry after
/// a failure) — `FakeModelCatalogClient` is a struct, so `AppModel` captures
/// its own copy at construction and later mutations of a caller's copy
/// wouldn't be visible to it.
final class ToggleableModelCatalogClient: ModelCatalogClient {
    var shouldFail: Bool
    var models: [String]

    init(shouldFail: Bool = false, models: [String] = []) {
        self.shouldFail = shouldFail
        self.models = models
    }

    func fetchModels(baseURL: URL) async throws -> [String] {
        if shouldFail { throw FakeModelCatalogClientError.failed }
        return models
    }
}

/// A `ModelCatalogClient` fake whose response depends on which `baseURL` it's
/// asked for, each with its own artificial delay — for testing that a slow
/// fetch for a Backend the user has since switched away from doesn't land
/// after (and overwrite results from) a faster, more recent fetch.
final class SlowModelCatalogClient: ModelCatalogClient {
    struct Response {
        let baseURL: URL
        let delayNanoseconds: UInt64
        var models: [String] = []
        var shouldFail: Bool = false
    }

    var responses: [Response] = []

    func fetchModels(baseURL: URL) async throws -> [String] {
        guard let response = responses.first(where: { $0.baseURL == baseURL }) else { return [] }
        try await Task.sleep(nanoseconds: response.delayNanoseconds)
        if response.shouldFail { throw FakeModelCatalogClientError.failed }
        return response.models
    }
}

/// A `ModelCatalogClient` fake with one configurable delay before resolving,
/// regardless of `baseURL` — for deterministically testing timeout behavior
/// (delay it past an injected `modelFetchTimeoutNanoseconds` to force
/// `.timedOut`, or keep it under to force a normal resolution).
final class DelayedModelCatalogClient: ModelCatalogClient {
    var delayNanoseconds: UInt64
    var models: [String]
    var shouldFail: Bool

    init(delayNanoseconds: UInt64, models: [String] = [], shouldFail: Bool = false) {
        self.delayNanoseconds = delayNanoseconds
        self.models = models
        self.shouldFail = shouldFail
    }

    func fetchModels(baseURL: URL) async throws -> [String] {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        if shouldFail { throw FakeModelCatalogClientError.failed }
        return models
    }
}

/// In-memory `PersistenceStore` fake. Reference type so a test can hold onto
/// the same instance passed into `AppModel.init` to pre-seed state (testing
/// load-on-launch) or inspect what was saved after a mutation.
final class FakePersistenceStore: PersistenceStore {
    var chats: [String: Chat] = [:]
    var currentChatId: String?
    var draft: String = ""
    var settings: PersistedSettings = .default
    private(set) var saveChatCallCount = 0
    private(set) var saveSettingsCallCount = 0

    func loadChats() -> [String: Chat] { chats }
    func loadCurrentChatId() -> String? { currentChatId }
    func loadDraft() -> String { draft }
    func loadSettings() -> PersistedSettings { settings }

    func saveChat(_ chat: Chat) {
        chats[chat.id] = chat
        saveChatCallCount += 1
    }

    func deleteChat(id: String) {
        chats.removeValue(forKey: id)
    }

    func saveCurrentChatId(_ currentChatId: String?) {
        self.currentChatId = currentChatId
    }

    func saveDraft(_ draft: String) {
        self.draft = draft
    }

    func saveSettings(_ settings: PersistedSettings) {
        self.settings = settings
        saveSettingsCallCount += 1
    }
}

/// Builds an `AppModel` wired with fakes by default, so tests never trigger
/// a real network call (e.g. via `AppModel.init`'s automatic initial model
/// load) unless they explicitly ask for one. The timeout/retry-backoff
/// durations default to millisecond scale (vs. production's 30s/5s) so
/// timeout- and retry-loop tests never actually wait on wall-clock time.
@MainActor
func makeTestAppModel(
    backendClient: ChatBackendClient = FakeChatBackendClient(),
    modelCatalogClient: ModelCatalogClient = FakeModelCatalogClient(),
    persistenceStore: PersistenceStore = FakePersistenceStore(),
    modelFetchTimeoutNanoseconds: UInt64 = 30_000_000,
    modelRetryBackoffNanoseconds: UInt64 = 10_000_000
) -> AppModel {
    AppModel(
        backendClient: backendClient,
        modelCatalogClient: modelCatalogClient,
        persistenceStore: persistenceStore,
        modelFetchTimeoutNanoseconds: modelFetchTimeoutNanoseconds,
        modelRetryBackoffNanoseconds: modelRetryBackoffNanoseconds
    )
}
