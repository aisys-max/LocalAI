import Foundation

/// Fetches installed Models from a Backend's OpenAI-compatible `/v1/models`
/// endpoint — see ADR-0001, same endpoint family as
/// `OpenAICompatibleChatBackendClient`.
struct OpenAICompatibleModelCatalogClient: ModelCatalogClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchModels(baseURL: URL) async throws -> [String] {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/models"))
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ModelCatalogClientError.badResponse
        }

        let decoded = try JSONDecoder().decode(ModelListResponse.self, from: data)
        return decoded.data.map(\.id)
    }
}

enum ModelCatalogClientError: Error {
    case badResponse
}

struct ModelListResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }
    let data: [Model]
}
