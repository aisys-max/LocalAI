import Testing
import Foundation
@testable import LocalAI

/// Direct tests of the pure Greeting append-vs-replace-vs-backfill decision
/// — no `AppModel`, `PersistenceStore`, or network client involved. The
/// wiring that calls this from `AppModel.reconcileGreetingForCurrentChat()`
/// (including the async/`goChat()`/launch timing around it) is covered
/// separately in `AppModelTests.swift`.
struct GreetingReconciliationTests {
    private func greeting(_ backend: Backend?, _ model: String?, createdAt: Date, id: String = UUID().uuidString) -> ChatMessage {
        ChatMessage(id: id, role: .assistant, text: "greeting", model: model, backend: backend, isGreeting: true, createdAt: createdAt)
    }

    private func makeGreeting(backend: Backend, model: String) -> (Date) -> ChatMessage {
        { createdAt in ChatMessage(id: UUID().uuidString, role: .assistant, text: "\(backend.label)/\(model)", model: model, backend: backend, isGreeting: true, createdAt: createdAt) }
    }

    private func updatedChat(_ result: GreetingReconciliationResult) -> Chat? {
        guard case .updated(let chat) = result else { return nil }
        return chat
    }

    @Test func unchangedBackendAndModelIsANoOp() {
        let chat = Chat(id: "c1", createdAt: Date(), title: "Chat", snippet: "hi", messages: [
            greeting(.ollama, "m1", createdAt: Date(timeIntervalSince1970: 1))
        ])
        let result = reconcileGreeting(in: chat, backend: .ollama, model: "m1", makeGreeting: makeGreeting(backend: .ollama, model: "m1"))
        guard case .unchanged = result else { Issue.record("expected .unchanged, got \(result)"); return }
    }

    @Test func noModelSelectedYetIsANoOp() {
        let chat = Chat(id: "c1", createdAt: Date(), title: "Chat", snippet: "hi", messages: [
            greeting(.ollama, "m1", createdAt: Date(timeIntervalSince1970: 1)),
            ChatMessage(id: "u1", role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 2))
        ])
        let result = reconcileGreeting(in: chat, backend: .lmstudio, model: nil, makeGreeting: makeGreeting(backend: .lmstudio, model: "unused"))
        guard case .unchanged = result else { Issue.record("expected .unchanged, got \(result)"); return }
    }

    @Test func realMessageAfterTheLastGreetingMakesASwitchAppendRatherThanReplace() {
        let chat = Chat(id: "c1", createdAt: Date(), title: "Chat", snippet: "hi", messages: [
            greeting(.ollama, "m1", createdAt: Date(timeIntervalSince1970: 1)),
            ChatMessage(id: "u1", role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 2))
        ])
        let result = reconcileGreeting(in: chat, backend: .lmstudio, model: "m2", makeGreeting: makeGreeting(backend: .lmstudio, model: "m2"))
        let greetings = updatedChat(result)?.messages.filter(\.isGreeting) ?? []
        #expect(greetings.count == 2)
        #expect(greetings.first?.backend == .ollama)
        #expect(greetings.first?.model == "m1")
        #expect(greetings.last?.backend == .lmstudio)
        #expect(greetings.last?.model == "m2")
    }

    @Test func onlyTheModelChangingStillAppends() {
        let chat = Chat(id: "c1", createdAt: Date(), title: "Chat", snippet: "hi", messages: [
            greeting(.ollama, "m1", createdAt: Date(timeIntervalSince1970: 1)),
            ChatMessage(id: "u1", role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 2))
        ])
        let result = reconcileGreeting(in: chat, backend: .ollama, model: "m2", makeGreeting: makeGreeting(backend: .ollama, model: "m2"))
        let greetings = updatedChat(result)?.messages.filter(\.isGreeting) ?? []
        #expect(greetings.count == 2)
        #expect(greetings.last?.backend == .ollama)
        #expect(greetings.last?.model == "m2")
    }

    @Test func aGreetingThatPredatesTheBackendFieldIsBackfilledInPlaceRatherThanTreatedAsAChange() {
        let original = Chat(id: "c1", createdAt: Date(), title: "Chat", snippet: "hi", messages: [
            greeting(nil, "m1", createdAt: Date(timeIntervalSince1970: 1), id: "g1"),
            ChatMessage(id: "u1", role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 2))
        ])
        let backfillResult = reconcileGreeting(in: original, backend: .ollama, model: "m1", makeGreeting: makeGreeting(backend: .ollama, model: "m1"))
        let backfilled = updatedChat(backfillResult)
        let backfilledGreetings = backfilled?.messages.filter(\.isGreeting) ?? []
        #expect(backfilledGreetings.count == 1)
        #expect(backfilledGreetings.first?.id == "g1")
        #expect(backfilledGreetings.first?.backend == .ollama)

        // A genuine subsequent switch is then detected correctly, on top of the backfill.
        let switchResult = reconcileGreeting(in: backfilled!, backend: .lmstudio, model: "m2", makeGreeting: makeGreeting(backend: .lmstudio, model: "m2"))
        let greetingsAfterSwitch = updatedChat(switchResult)?.messages.filter(\.isGreeting) ?? []
        #expect(greetingsAfterSwitch.count == 2)
        #expect(greetingsAfterSwitch.last?.backend == .lmstudio)
    }

    @Test func modelUnknownAtGreetingTimeRegeneratesInPlaceOncePreservingItsCreatedAtOnceAModelResolves() {
        let createdAt = Date(timeIntervalSince1970: 1)
        let chat = Chat(id: "c1", createdAt: createdAt, title: "Chat", snippet: "hi", messages: [
            greeting(.ollama, nil, createdAt: createdAt, id: "g1")
        ])
        let result = reconcileGreeting(in: chat, backend: .ollama, model: "m2", makeGreeting: makeGreeting(backend: .ollama, model: "m2"))
        let updated = updatedChat(result)
        #expect(updated?.messages.count == 1)
        #expect(updated?.messages.first?.model == "m2")
        #expect(updated?.messages.first?.backend == .ollama)
        // Regenerated in place, not treated as a switch worth logging — the
        // original occurrence's timestamp is preserved, not replaced with `now`.
        #expect(updated?.messages.first?.createdAt == createdAt)
    }

    @Test func repeatedlySwitchingOnAStillEmptyChatNeverAccumulatesGreetings() {
        let chat = Chat(id: "c1", createdAt: Date(), title: "Chat", snippet: "hi", messages: [
            greeting(.ollama, "m1", createdAt: Date(timeIntervalSince1970: 1))
        ])
        let afterFirst = updatedChat(reconcileGreeting(in: chat, backend: .lmstudio, model: "m2", makeGreeting: makeGreeting(backend: .lmstudio, model: "m2")))!
        let afterSecond = updatedChat(reconcileGreeting(in: afterFirst, backend: .ollama, model: "m3", makeGreeting: makeGreeting(backend: .ollama, model: "m3")))!
        let afterThird = updatedChat(reconcileGreeting(in: afterSecond, backend: .lmstudio, model: "m4", makeGreeting: makeGreeting(backend: .lmstudio, model: "m4")))!

        let greetings = afterThird.messages.filter(\.isGreeting)
        #expect(greetings.count == 1)
        #expect(greetings.first?.backend == .lmstudio)
        #expect(greetings.first?.model == "m4")
    }

    @Test func deletingTheOnlyRealMessageThenSwitchingBackendReplacesOnlyTheLastGreeting() {
        // Simulates: greeting(ollama/m1), user "hi", greeting(lmstudio/m2), then
        // the user Message was deleted — nothing real left after either Greeting.
        let chat = Chat(id: "c1", createdAt: Date(), title: "Chat", snippet: "hi", messages: [
            greeting(.ollama, "m1", createdAt: Date(timeIntervalSince1970: 1), id: "g1"),
            greeting(.lmstudio, "m2", createdAt: Date(timeIntervalSince1970: 2), id: "g2")
        ])
        let result = reconcileGreeting(in: chat, backend: .ollama, model: "m1", makeGreeting: makeGreeting(backend: .ollama, model: "m1"))
        let greetings = updatedChat(result)?.messages.filter(\.isGreeting) ?? []
        #expect(greetings.count == 2)
        #expect(greetings.first?.id == "g1")
        #expect(greetings.first?.backend == .ollama)
        #expect(greetings.first?.model == "m1")
        #expect(greetings.last?.backend == .ollama)
        #expect(greetings.last?.model == "m1")
        // Same content, but genuinely the replaced-in-place last Greeting,
        // not the untouched first one.
        #expect(greetings.first?.id != greetings.last?.id)
    }

    @Test func returningToAnUnstartedChatAfterABackendSwitchReplacesItsSoleGreeting() {
        let chat = Chat(id: "c1", createdAt: Date(), title: "Chat", snippet: "hi", messages: [
            greeting(.ollama, "m1", createdAt: Date(timeIntervalSince1970: 1))
        ])
        let result = reconcileGreeting(in: chat, backend: .lmstudio, model: "m2", makeGreeting: makeGreeting(backend: .lmstudio, model: "m2"))
        let messages = updatedChat(result)?.messages ?? []
        #expect(messages.count == 1)
        #expect(messages.first?.isGreeting == true)
        #expect(messages.first?.backend == .lmstudio)
        #expect(messages.first?.model == "m2")
    }

    @Test func switchingBackToAnEarlierBackendModelAfterFurtherConversationStillAppendsRatherThanDeduping() {
        let chat = Chat(id: "c1", createdAt: Date(), title: "Chat", snippet: "hi", messages: [
            greeting(.ollama, "m1", createdAt: Date(timeIntervalSince1970: 1)),
            ChatMessage(id: "u1", role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 2)),
            greeting(.lmstudio, "m2", createdAt: Date(timeIntervalSince1970: 3)),
            ChatMessage(id: "u2", role: .user, text: "hi again", createdAt: Date(timeIntervalSince1970: 4))
        ])
        let result = reconcileGreeting(in: chat, backend: .ollama, model: "m1", makeGreeting: makeGreeting(backend: .ollama, model: "m1"))
        let greetings = updatedChat(result)?.messages.filter(\.isGreeting) ?? []
        #expect(greetings.count == 3)
        #expect(greetings.last?.backend == .ollama)
        #expect(greetings.last?.model == "m1")
    }

    @Test func switchingBackendAgainWithoutFurtherConversationReplacesTheJustAppendedGreeting() {
        // Now: [greeting(ollama/m1), user "hi", greeting(lmstudio/m2)] — no
        // real Message sent since the lmstudio/m2 Greeting.
        let chat = Chat(id: "c1", createdAt: Date(), title: "Chat", snippet: "hi", messages: [
            greeting(.ollama, "m1", createdAt: Date(timeIntervalSince1970: 1), id: "g1"),
            ChatMessage(id: "u1", role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 2)),
            greeting(.lmstudio, "m2", createdAt: Date(timeIntervalSince1970: 3), id: "g2")
        ])
        let result = reconcileGreeting(in: chat, backend: .ollama, model: "m1", makeGreeting: makeGreeting(backend: .ollama, model: "m1"))
        let greetings = updatedChat(result)?.messages.filter(\.isGreeting) ?? []
        #expect(greetings.count == 2)
        #expect(greetings.first?.id == "g1")
        #expect(greetings.first?.backend == .ollama)
        #expect(greetings.first?.model == "m1")
        #expect(greetings.last?.backend == .ollama)
        #expect(greetings.last?.model == "m1")
        #expect(greetings.first?.id != greetings.last?.id)
    }
}
