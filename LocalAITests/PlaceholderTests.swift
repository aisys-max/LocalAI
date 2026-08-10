import Testing

@Suite struct PlaceholderTests {
    @Test func testTargetBuilds() {
        #expect(1 + 1 == 2)
    }
}
