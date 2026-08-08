import Foundation

enum Backend: String, CaseIterable, Identifiable {
    case ollama
    case lmstudio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ollama: return "Ollama"
        case .lmstudio: return "LM Studio"
        }
    }

    var models: [String] {
        switch self {
        case .ollama:
            return ["Llama 3.1 8B", "Mistral 7B", "Gemma 2 9B", "Phi-3 Mini"]
        case .lmstudio:
            return ["Llama 3.1 8B Instruct (GGUF)", "Qwen2.5 7B Instruct", "Mistral 7B Instruct v0.3", "DeepSeek-Coder 6.7B"]
        }
    }

    func description(_ language: AppLanguage) -> String {
        switch self {
        case .ollama: return language.strings.ollamaDesc
        case .lmstudio: return language.strings.lmstudioDesc
        }
    }
}
