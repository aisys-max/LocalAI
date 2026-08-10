import Foundation

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
