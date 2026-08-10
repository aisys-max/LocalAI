---
status: accepted
---

# Stream replies via AsyncThrowingStream

`ChatBackendClient.generateReply` moves from `async -> String` (wait for the full canned reply, then return it) to a streaming shape returning `AsyncThrowingStream<String, Error>` of text chunks, so real Backend replies can render progressively instead of appearing all at once. `AsyncThrowingStream` was chosen over a callback closure or a Combine publisher because `AppModel+Chat.swift`'s call sites (`sendMessage`, `regenerate`) are already `async`/`await`-based and can consume it with `for try await`. This is a breaking change to the protocol's call sites and to how `TypingIndicatorView`/`MessageBubbleView` receive text, so reverting to single-shot replies later means changing the protocol signature again.
