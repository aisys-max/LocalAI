import Foundation

/// The outcome of `reconcileGreeting(in:backend:model:now:makeGreeting:)` —
/// distinguishes "nothing to persist" from "write this Chat back."
enum GreetingReconciliationResult {
    case unchanged
    case updated(Chat)
}

/// Reconciles `chat`'s most recent Greeting against the currently selected
/// (`backend`, `model`) — the product rule described under "Greeting" in
/// CONTEXT.md. No-op if the Chat has no Greeting at all, or if `model` is
/// nil: `AppModel.selectBackend(_:)` clears `model` before a fresh fetch
/// resolves, and reconciling against that transient nil would permanently
/// bake a "no model" Greeting into history for what's normally a brief
/// window.
///
/// `makeGreeting` builds a fresh Greeting `ChatMessage` for the given
/// `createdAt` — callers pass `AppModel.greetingMessage(createdAt:)` so this
/// function never needs to know how Greeting text is rendered.
func reconcileGreeting(
    in chat: Chat,
    backend: Backend,
    model: String?,
    now: Date = Date(),
    makeGreeting: (Date) -> ChatMessage
) -> GreetingReconciliationResult {
    guard let model, let lastGreetingIndex = chat.messages.lastIndex(where: { $0.isGreeting }) else {
        return .unchanged
    }
    var chat = chat
    let lastGreeting = chat.messages[lastGreetingIndex]

    guard let lastBackend = lastGreeting.backend else {
        // Predates the `backend` field — there's no way to tell whether a
        // switch actually happened, so this backfills the field in place
        // rather than guessing at history.
        chat.messages[lastGreetingIndex].backend = backend
        return .updated(chat)
    }

    if lastGreeting.model == nil && lastBackend == backend {
        // The Model wasn't known yet when this Greeting was created — e.g.
        // bootstrapped at launch, or written while a Backend switch's async
        // Model fetch was still in flight. Now that a Model is known (the
        // guard above requires it) and the Backend hasn't also changed,
        // this regenerates the Greeting in place rather than treating "we
        // now know the Model" as a real switch worth logging — otherwise
        // every Chat greeted before its first Model resolves would get a
        // spurious extra Greeting the moment that resolution lands.
        chat.messages[lastGreetingIndex] = makeGreeting(lastGreeting.createdAt)
        return .updated(chat)
    }

    guard lastBackend != backend || lastGreeting.model != model else { return .unchanged }

    let newGreeting = makeGreeting(now)
    // Append-vs-replace is judged from what happened *since the last
    // Greeting specifically* — not the Chat's full history. A Chat can pick
    // up several Greetings over its lifetime (one per switch that actually
    // had a real Message after it); switching again right after an earlier
    // switch, with nothing sent in between, updates that same last Greeting
    // in place instead of piling up an entry for a switch nobody actually
    // used. This is also what makes a still-fully-unstarted Chat behave as
    // a special case of the same rule (its one Greeting has nothing after
    // it either), rather than needing its own branch.
    let messagesSinceLastGreeting = chat.messages[(lastGreetingIndex + 1)...]
    if messagesSinceLastGreeting.contains(where: { !$0.isGreeting }) {
        chat.messages.append(newGreeting)
    } else {
        chat.messages[lastGreetingIndex] = newGreeting
    }
    chat.snippet = String(newGreeting.text.prefix(60))
    return .updated(chat)
}
