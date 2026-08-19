import Testing
import Foundation
@testable import LocalAI

@Suite(.tags(.networking))
struct OpenAICompatibleModelCatalogClientTests {
    private let testBaseURL = URL(string: "http://localhost:11434")!

    @Test func requestIsAGetToVModels() async throws {
        StubURLProtocol.stub(status: 200, body: modelsBody(["gpt-oss:20b"]))
        let client = OpenAICompatibleModelCatalogClient(session: stubbedSession())

        _ = try await client.fetchModels(baseURL: testBaseURL)

        let request = try #require(StubURLProtocol.capturedRequest)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "http://localhost:11434/v1/models")
    }

    @Test func successResponseDecodesModelIdsInOrder() async throws {
        StubURLProtocol.stub(status: 200, body: modelsBody(["llama3", "mistral", "gemma2"]))
        let client = OpenAICompatibleModelCatalogClient(session: stubbedSession())

        let models = try await client.fetchModels(baseURL: testBaseURL)

        #expect(models == ["llama3", "mistral", "gemma2"])
    }

    @Test func emptyModelListDecodesAsAnEmptyArrayNotAnError() async throws {
        StubURLProtocol.stub(status: 200, body: modelsBody([]))
        let client = OpenAICompatibleModelCatalogClient(session: stubbedSession())

        let models = try await client.fetchModels(baseURL: testBaseURL)

        #expect(models == [])
    }

    @Test func nonSuccessResponseThrows() async throws {
        StubURLProtocol.stub(status: 500, body: Data())
        let client = OpenAICompatibleModelCatalogClient(session: stubbedSession())

        await #expect(throws: ModelCatalogClientError.badResponse) {
            _ = try await client.fetchModels(baseURL: testBaseURL)
        }
    }

    @Test func malformedResponseBodyThrows() async throws {
        StubURLProtocol.stub(status: 200, body: "not json".data(using: .utf8)!)
        let client = OpenAICompatibleModelCatalogClient(session: stubbedSession())

        await #expect(throws: DecodingError.self) {
            _ = try await client.fetchModels(baseURL: testBaseURL)
        }
    }

    private func stubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func modelsBody(_ ids: [String]) -> Data {
        let entries = ids.map { "{\"id\":\"\($0)\",\"object\":\"model\"}" }.joined(separator: ",")
        return "{\"object\":\"list\",\"data\":[\(entries)]}".data(using: .utf8)!
    }
}
