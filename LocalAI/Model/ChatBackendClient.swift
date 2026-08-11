import Foundation

/// Generates chat replies as a stream of text chunks. `SimulatedChatBackendClient`
/// is the current stand-in for a real Ollama/LM Studio client — swap the
/// implementation passed into `AppModel.init(backendClient:)` when a real
/// backend is wired up.
protocol ChatBackendClient {
    func generateReply(chatId: String, model: String, messages: [ChatMessage], delayNanoseconds: UInt64) -> AsyncThrowingStream<String, Error>
}

struct SimulatedChatBackendClient: ChatBackendClient {
    func generateReply(chatId: String, model: String, messages: [ChatMessage], delayNanoseconds: UInt64) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
                continuation.yield(CannedReplies.random())
                continuation.finish()
            }
        }
    }
}

/// Port of the design's `CANNED_REPLIES` — fixed simulated responses used when no
/// real Ollama/LM Studio backend is wired up.
enum CannedReplies {
    static let all: [String] = [
        "Here's a quick summary:\n\n- Key point noted\n- Follow-up scheduled\n- Nothing left to your imagination — this ran fully offline",
        "Here's a small script:\n```python\nimport os\nfor f in sorted(os.listdir('.')):\n    print(f)\n```\nRun it from the folder you want to list.",
        "Good options: a sheet-pan bake, a quick curry, or a simple skillet — all work well with rice or crusty bread.",
        "The short version: it depends on your goal, but starting simple and iterating from there usually wins. Want me to go deeper on one part?",
    ]

    static func random() -> String { all.randomElement()! }
}
