import Testing

@Suite("Flirty Tests")
struct FlirtyTests {
    @Test("App exists")
    func appExists() {
        #expect(true)
    }
}
