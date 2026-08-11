import Foundation

/// Fetches the list of Models available on a Backend. Separate from
/// `ChatBackendClient` — generating replies and discovering models are
/// distinct responsibilities with distinct failure modes (a chat request
/// failing mid-stream is not the same as a model list never loading).
protocol ModelCatalogClient {
    func fetchModels(baseURL: URL) async throws -> [String]
}

/// Canned stand-in for a real Backend's model catalog, kept for SwiftUI
/// previews and network-free unit tests.
struct SimulatedModelCatalogClient: ModelCatalogClient {
    func fetchModels(baseURL: URL) async throws -> [String] {
        ["Llama 3.1 8B", "Mistral 7B", "Gemma 2 9B"]
    }
}

/// The state of a Backend's Model list fetch, driving the loading/error/list
/// UI in `ModelStepView` and `ModelPickerView`.
enum ModelListState: Equatable {
    case loading
    case loaded([String])
    case failed
}
