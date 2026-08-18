import Testing
@testable import LocalAI

struct BackendTests {
    @Test func remoteAccessHintReturnsTheOllamaHintForEachLanguage() {
        #expect(Backend.ollama.remoteAccessHint(.en) == Strings.en.ollamaRemoteHint)
        #expect(Backend.ollama.remoteAccessHint(.ko) == Strings.ko.ollamaRemoteHint)
    }

    @Test func remoteAccessHintReturnsTheLMStudioHintForEachLanguage() {
        #expect(Backend.lmstudio.remoteAccessHint(.en) == Strings.en.lmstudioRemoteHint)
        #expect(Backend.lmstudio.remoteAccessHint(.ko) == Strings.ko.lmstudioRemoteHint)
    }

    @Test func remoteAccessHintDoesNotMixUpTheTwoBackends() {
        #expect(Backend.ollama.remoteAccessHint(.en) != Backend.lmstudio.remoteAccessHint(.en))
        #expect(Backend.ollama.remoteAccessHint(.ko) != Backend.lmstudio.remoteAccessHint(.ko))
    }
}
