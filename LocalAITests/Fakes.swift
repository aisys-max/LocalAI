import Foundation
@testable import LocalAI

struct FakeChatBackendClient: ChatBackendClient {
    var reply: String = "fake reply"
    var chunks: [String]?

    func generateReply(chatId: String, model: String, messages: [ChatMessage], baseURL: URL, delayNanoseconds: UInt64) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks ?? [reply] {
                continuation.yield(chunk)
            }
            continuation.finish()
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
        let models: [String]
    }

    var responses: [Response] = []

    func fetchModels(baseURL: URL) async throws -> [String] {
        guard let response = responses.first(where: { $0.baseURL == baseURL }) else { return [] }
        try await Task.sleep(nanoseconds: response.delayNanoseconds)
        return response.models
    }
}

/// Builds an `AppModel` wired with fakes by default, so tests never trigger
/// a real network call (e.g. via `AppModel.init`'s automatic initial model
/// load) unless they explicitly ask for one.
@MainActor
func makeTestAppModel(
    backendClient: ChatBackendClient = FakeChatBackendClient(),
    modelCatalogClient: ModelCatalogClient = FakeModelCatalogClient()
) -> AppModel {
    AppModel(backendClient: backendClient, modelCatalogClient: modelCatalogClient)
}
