import Foundation

enum ChatDay: String {
    case today, yesterday, previous7
}

enum MessageRole {
    case user, assistant
}

struct InlinePart: Identifiable {
    let id = UUID()
    let bold: Bool
    let text: String
}

enum MessageBlock: Identifiable {
    case code(id: UUID, text: String)
    case text(id: UUID, parts: [InlinePart])

    var id: UUID {
        switch self {
        case .code(let id, _): return id
        case .text(let id, _): return id
        }
    }
}

struct ChatMessage: Identifiable {
    let id: String
    let role: MessageRole
    var text: String
    var model: String?
}

struct Chat: Identifiable {
    let id: String
    var day: ChatDay
    var title: String
    var snippet: String
    var messages: [ChatMessage]
}

/// Ports the design's `parseBlocks`/`parseInline` markdown-lite renderer:
/// fenced ``` code blocks, and **bold** spans within the remaining text.
enum MessageParsing {
    private static let codeBlockRegex = try! NSRegularExpression(
        pattern: "```(?:\\w+)?\\n?(.*?)```",
        options: [.dotMatchesLineSeparators]
    )
    private static let boldRegex = try! NSRegularExpression(
        pattern: "\\*\\*(.*?)\\*\\*",
        options: [.dotMatchesLineSeparators]
    )

    static func blocks(from text: String) -> [MessageBlock] {
        var blocks: [MessageBlock] = []
        let ns = text as NSString
        var last = 0
        let matches = codeBlockRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            if match.range.location > last {
                let plain = ns.substring(with: NSRange(location: last, length: match.range.location - last))
                blocks.append(.text(id: UUID(), parts: inlineParts(from: plain)))
            }
            var code = ns.substring(with: match.range(at: 1))
            if code.hasSuffix("\n") { code.removeLast() }
            blocks.append(.code(id: UUID(), text: code))
            last = match.range.location + match.range.length
        }
        if last < ns.length {
            let plain = ns.substring(with: NSRange(location: last, length: ns.length - last))
            blocks.append(.text(id: UUID(), parts: inlineParts(from: plain)))
        }
        if blocks.isEmpty {
            blocks.append(.text(id: UUID(), parts: []))
        }
        return blocks
    }

    static func inlineParts(from text: String) -> [InlinePart] {
        var parts: [InlinePart] = []
        let ns = text as NSString
        var last = 0
        let matches = boldRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            if match.range.location > last {
                parts.append(InlinePart(bold: false, text: ns.substring(with: NSRange(location: last, length: match.range.location - last))))
            }
            parts.append(InlinePart(bold: true, text: ns.substring(with: match.range(at: 1))))
            last = match.range.location + match.range.length
        }
        if last < ns.length {
            parts.append(InlinePart(bold: false, text: ns.substring(with: NSRange(location: last, length: ns.length - last))))
        }
        if parts.isEmpty {
            parts.append(InlinePart(bold: false, text: ""))
        }
        return parts
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

/// Port of the design's `makeSeedChats()`.
enum SeedChats {
    static func make() -> [Chat] {
        [
            Chat(id: "h1", day: .today, title: "Summarize meeting notes", snippet: "Here's a quick summary:", messages: [
                ChatMessage(id: "h1-1", role: .user, text: "Summarize this meeting: we discussed Q3 roadmap, agreed to delay the redesign, and need budget signoff by Friday."),
                ChatMessage(id: "h1-2", role: .assistant, text: "Here's a quick summary:\n\n- Q3 roadmap reviewed\n- Redesign delayed\n- Budget signoff needed by Friday", model: "Llama 3.1 8B"),
            ]),
            Chat(id: "h2", day: .today, title: "Python file sorter script", snippet: "Run it from the folder you want to list.", messages: [
                ChatMessage(id: "h2-1", role: .user, text: "Write a short script that lists files in the current folder, sorted alphabetically."),
                ChatMessage(id: "h2-2", role: .assistant, text: "Here's a small script:\n```python\nimport os\nfor f in sorted(os.listdir('.')):\n    print(f)\n```\nRun it from the folder you want to list.", model: "Llama 3.1 8B"),
            ]),
            Chat(id: "h3", day: .yesterday, title: "Recipe ideas with chicken", snippet: "Good options for chicken thighs:", messages: [
                ChatMessage(id: "h3-1", role: .user, text: "Give me a few dinner ideas using chicken thighs."),
                ChatMessage(id: "h3-2", role: .assistant, text: "Good options for chicken: a sheet-pan lemon and herb bake, a quick coconut curry, or a simple garlic and paprika skillet. All work well with rice or crusty bread.", model: "Mistral 7B"),
            ]),
            Chat(id: "h4", day: .previous7, title: "Explain quantum entanglement", snippet: "Entanglement means two particles share...", messages: [
                ChatMessage(id: "h4-1", role: .user, text: "Explain quantum entanglement simply."),
                ChatMessage(id: "h4-2", role: .assistant, text: "Entanglement means two particles share a single quantum state. Measuring one instantly determines the outcome for the other, no matter the distance between them, though no information travels faster than light in the process.", model: "Gemma 2 9B"),
            ]),
            Chat(id: "h5", day: .previous7, title: "Debug React useEffect loop", snippet: "The infinite loop is almost always...", messages: [
                ChatMessage(id: "h5-1", role: .user, text: "My useEffect keeps firing in an infinite loop, why?"),
                ChatMessage(id: "h5-2", role: .assistant, text: "The infinite loop is almost always a dependency that changes every render. Move the object or function you're passing into the dependency array into useMemo or useCallback, or narrow the dependency to the specific field you actually read.", model: "Qwen2.5 7B Instruct"),
            ]),
        ]
    }
}
