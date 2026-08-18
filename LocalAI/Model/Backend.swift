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

    var defaultServerAddress: String {
        switch self {
        case .ollama: return "http://localhost:11434"
        case .lmstudio: return "http://localhost:1234"
        }
    }

    func description(_ language: AppLanguage) -> String {
        switch self {
        case .ollama: return language.strings.ollamaDesc
        case .lmstudio: return language.strings.lmstudioDesc
        }
    }

    func remoteAccessHint(_ language: AppLanguage) -> String {
        switch self {
        case .ollama: return language.strings.ollamaRemoteHint
        case .lmstudio: return language.strings.lmstudioRemoteHint
        }
    }
}
