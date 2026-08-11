import Testing
import Foundation
@testable import LocalAI

@Suite struct ModelCatalogClientTests {
    @Test func simulatedCatalogReturnsANonEmptyFixedList() async throws {
        let client = SimulatedModelCatalogClient()
        let models = try await client.fetchModels(baseURL: URL(string: "http://localhost:11434")!)
        #expect(!models.isEmpty)
    }

    @Test func simulatedCatalogIsConsistentAcrossRepeatedCalls() async throws {
        let client = SimulatedModelCatalogClient()
        let first = try await client.fetchModels(baseURL: URL(string: "http://localhost:11434")!)
        let second = try await client.fetchModels(baseURL: URL(string: "http://localhost:11434")!)
        #expect(first == second)
    }
}
